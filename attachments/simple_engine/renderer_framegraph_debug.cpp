#include "renderer.h"
#include "frame_graph_debug_vulkan.h"
#include <cstring>


void Renderer::beginFrameGraphDebug(uint32_t imageIndex) {
    ++frameGraphDebugSerial;
    frameGraphDebugCapture.Cancel();
    auto& state = frameGraphDebugViewer;
    state.singleCapture = state.captureNext;
    if (!state.open || (state.frozen && !state.singleCapture)) return;

    frame_debug::Snapshot metadata;
    metadata.serial = frameGraphDebugSerial;
    metadata.frameSlot = currentFrame;
    metadata.frameSlots = MAX_FRAMES_IN_FLIGHT;
    metadata.swapchainImage = imageIndex;
    metadata.swapchainImages = static_cast<uint32_t>(swapChainImages.size());
    metadata.width = swapChainExtent.width;
    metadata.height = swapChainExtent.height;
    metadata.mode = currentRenderMode == RenderMode::RayQuery ? "Ray query requested" : "Raster";
    frameGraphDebugCapture.Begin(std::move(metadata));
    auto image = [&](const char* name, vk::Image handle, vk::Format format, uint32_t w, uint32_t h,
                     frame_debug::Scope scope, uint32_t count, uint32_t selected, const char* notes) {
        if (!handle) return;
        frame_debug::Resource resource;
        resource.name = name;
        resource.format = vk::to_string(format);
        resource.width = w; resource.height = h;
        resource.scope = scope; resource.instances = count; resource.selectedInstance = selected;
        resource.handle = FrameGraphDebugHandle(handle);
        resource.notes = notes;
        frameGraphDebugCapture.AddResource(std::move(resource));
    };
    auto buffer = [&](const char* name, vk::Buffer handle, frame_debug::Scope scope,
                      uint32_t count, uint64_t bytes = 0) {
        if (!handle) return;
        frame_debug::Resource resource;
        resource.name = name; resource.kind = "Buffer"; resource.scope = scope;
        resource.instances = count; resource.selectedInstance = scope == frame_debug::Scope::FrameSlot ? currentFrame : 0;
        resource.handle = FrameGraphDebugHandle(handle); resource.bytes = bytes;
        frameGraphDebugCapture.AddResource(std::move(resource));
    };
    using frame_debug::Scope;
    image("Swapchain color", swapChainImages[imageIndex], swapChainImageFormat,
          swapChainExtent.width, swapChainExtent.height, Scope::Swapchain,
          static_cast<uint32_t>(swapChainImages.size()), imageIndex, "Acquired by image index, independently of the frame slot.");
    if (currentFrame < opaqueSceneColorImages.size())
        image("Opaque scene color", *opaqueSceneColorImages[currentFrame], swapChainImageFormat,
              swapChainExtent.width, swapChainExtent.height, Scope::FrameSlot,
              static_cast<uint32_t>(opaqueSceneColorImages.size()), currentFrame, "Color attachment and sampled image.");
    image("Scene depth", *depthImage, findDepthFormat(), swapChainExtent.width, swapChainExtent.height,
          Scope::Shared, 1, 0, "Single depth image shared by frame slots; synchronization remains the renderer's responsibility.");
    image("Ray query output", *rayQueryOutputImage, rayQueryOutputFormat,
          swapChainExtent.width, swapChainExtent.height, Scope::Shared, 1, 0, "Storage image and sampled image; shared by frame slots.");
    image("Transmittance LUT", *transmittanceLUTImage, vk::Format::eR16G16B16A16Sfloat,
          256, 64, Scope::Shared, 1, 0, "Regenerated only when atmosphere parameters are dirty.");
    image("Multi-scatter LUT", *multiScatterLUTImage, vk::Format::eR16G16B16A16Sfloat,
          32, 32, Scope::Shared, 1, 0, "Persistent atmosphere resource.");
    image("Sky-view LUT", *skyViewLUTImage, vk::Format::eR16G16B16A16Sfloat,
          192, 128, Scope::Shared, 1, 0, "Updated by the sky-view compute pass.");
    buffer("Atmosphere parameters", *atmosphereParamsBuffer, Scope::Shared, 1, sizeof(AtmosphereParameters));
    if (currentFrame < skyViewParamsBuffers.size())
        buffer("Sky-view parameters", *skyViewParamsBuffers[currentFrame], Scope::FrameSlot,
               static_cast<uint32_t>(skyViewParamsBuffers.size()), sizeof(SkyViewParamsGPU));
    if (currentFrame < rayQueryUniformBuffers.size())
        buffer("Ray query parameters", *rayQueryUniformBuffers[currentFrame], Scope::FrameSlot,
               static_cast<uint32_t>(rayQueryUniformBuffers.size()), sizeof(RayQueryUniformBufferObject));
    buffer("Geometry table", *geometryInfoBuffer, Scope::Shared, 1, geometryInfoAllocation ? geometryInfoAllocation->size : 0);
    buffer("Material table", *materialBuffer, Scope::Shared, 1, materialAllocation ? materialAllocation->size : 0);
    if (currentFrame < lightStorageBuffers.size()) {
        const auto& lights = lightStorageBuffers[currentFrame];
        buffer("Lights", *lights.buffer, Scope::FrameSlot, static_cast<uint32_t>(lightStorageBuffers.size()),
               lights.allocation ? lights.allocation->size : 0);
    }
    if (currentFrame < forwardPlusPerFrame.size()) {
        const auto& fp = forwardPlusPerFrame[currentFrame];
        const auto count = static_cast<uint32_t>(forwardPlusPerFrame.size());
        buffer("Light tile headers", *fp.tileHeaders, Scope::FrameSlot, count, fp.tileHeadersAlloc ? fp.tileHeadersAlloc->size : 0);
        buffer("Light tile indices", *fp.tileLightIndices, Scope::FrameSlot, count, fp.tileLightIndicesAlloc ? fp.tileLightIndicesAlloc->size : 0);
        buffer("Forward+ parameters", *fp.params, Scope::FrameSlot, count);
    }
    frame_debug::Resource textures;
    textures.name = "Material textures"; textures.kind = "Texture collection";
    textures.scope = Scope::Shared;
    { std::shared_lock lock(textureResourcesMutex); textures.instances = static_cast<uint32_t>(textureResources.size()); }
    textures.notes = "Loaded texture cache; formats and sizes vary. This collection is not expanded into individual graph images.";
    frameGraphDebugCapture.AddResource(std::move(textures));
    if (*tlasStructure.handle) {
        frame_debug::Resource tlas;
        tlas.name = "Scene TLAS"; tlas.kind = "Acceleration structure"; tlas.scope = Scope::Shared;
        tlas.instances = 1; tlas.handle = FrameGraphDebugHandle(*tlasStructure.handle);
        tlas.notes = "Imported into the recorded frame; AS build/refit and BLAS storage are not expanded here.";
        frameGraphDebugCapture.AddResource(std::move(tlas));
    }
}

void Renderer::finishFrameGraphDebug() {
    if (!frameGraphDebugViewer.frozen || frameGraphDebugViewer.singleCapture) frameGraphDebugCapture.Publish();
    else frameGraphDebugCapture.Cancel();
    if (frameGraphDebugViewer.singleCapture) frameGraphDebugViewer.captureNext = false;
    frameGraphDebugViewer.singleCapture = false;
}

void Renderer::drawFrameGraphDebugViewer() {
    frame_debug::DrawViewer(frameGraphDebugViewer, frameGraphDebugCapture.Latest());
}
