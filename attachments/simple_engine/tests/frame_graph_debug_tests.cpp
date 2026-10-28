#include "frame_graph_debug.h"
#include "imgui/imgui.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <cstdlib>

#undef assert
#define assert(condition) do { if (!(condition)) { std::cerr << "FAILED line " << __LINE__ << ": " << #condition << '\n'; std::exit(1); } } while (false)

using namespace frame_debug;

Snapshot Example() {
    Capture capture;
    Snapshot metadata;
    metadata.serial = 42; metadata.mode = "Raster";
    metadata.frameSlots = 2; metadata.frameSlot = 1;
    metadata.swapchainImages = 3; metadata.swapchainImage = 2;
    metadata.width = 1280; metadata.height = 720;
    capture.Begin(metadata);
    Resource color; color.name = "Opaque scene color"; color.format = "R16G16B16A16Sfloat";
    color.width = 1280; color.height = 720; color.scope = Scope::FrameSlot; color.instances = 2; color.selectedInstance = 1;
    color.handle = 0x123456789abcdef0ULL;
    capture.AddResource(color);
    Resource swap = color; swap.name = "Swapchain color"; swap.format = "B8G8R8A8Srgb"; swap.scope = Scope::Swapchain; swap.instances = 3; swap.selectedInstance = 2;
    capture.AddResource(swap);
    capture.BeginPass("Opaque scene", PassKind::Graphics);
    capture.Pipeline("PBR", 0x111); capture.Descriptor(0, "Entity PBR current frame", 0x222);
    capture.UseResource(color.name, Access::Write, "Color attachment (clear/store)", "ColorAttachmentOptimal");
    capture.UseResource("Material textures", Access::Read, "Sampled material maps", "ShaderReadOnlyOptimal", "set 0 bindings 1-5");
    capture.Draw(72);
    capture.BeginPass("Raster composite", PassKind::Graphics);
    capture.UseResource(color.name, Access::Read, "Sampled image", "ShaderReadOnlyOptimal", "set 0 binding 0");
    capture.UseResource(swap.name, Access::Write, "Color attachment (clear/store)", "ColorAttachmentOptimal");
    capture.Pipeline("composite.slang", 0x333); capture.Descriptor(0, "Raster composite current frame", 0x444);
    capture.Transition(color.name, "ColorAttachmentOptimal", "ShaderReadOnlyOptimal", "ColorAttachmentOutput / ColorAttachmentWrite", "FragmentShader / ShaderRead");
    capture.Draw();
    capture.BeginPass("Transparent scene", PassKind::Graphics);
    capture.UseResource(color.name, Access::Read, "Refraction background", "ShaderReadOnlyOptimal", "set 1 binding 0");
    capture.UseResource(swap.name, Access::ReadWrite, "Color attachment (load/store, blending)", "ColorAttachmentOptimal");
    capture.Draw(3);
    capture.BeginPass("ImGui overlay", PassKind::Graphics);
    capture.UseResource(swap.name, Access::ReadWrite, "Color attachment (load/store, blending)", "ColorAttachmentOptimal");
    capture.Draw(18);
    capture.BeginPass("Present", PassKind::Present);
    capture.UseResource(swap.name, Access::Read, "Presentation engine", "PresentSrcKHR");
    capture.Publish();
    return capture.Latest();
}

void ModelTests() {
    Capture capture;
    capture.BeginPass("Ignored", PassKind::Compute); capture.Draw(); capture.Publish();
    assert(capture.Latest().passes.empty());
    capture.Begin({});
    capture.BeginPass("Producer", PassKind::Compute);
    capture.UseResource("A", Access::Write, "Storage image");
    capture.UseResource("A", Access::Write, "Storage image"); // Merged annotation.
    capture.BeginPass("Reader 1", PassKind::Graphics); capture.UseResource("A", Access::Read, "Sampled image");
    capture.BeginPass("Reader 2", PassKind::Compute); capture.UseResource("A", Access::Read, "Sampled image");
    capture.BeginPass("Overwrite", PassKind::Compute); capture.UseResource("A", Access::Write, "Storage image");
    capture.Publish();
    assert(capture.Latest().edges.size() == 5);
    assert(capture.Latest().passes[0].uses.size() == 1);
    unsigned raw = 0, war = 0, waw = 0;
    for (const auto& edge : capture.Latest().edges) {
        assert(edge.from < edge.to);
        raw += edge.hazard == Hazard::ReadAfterWrite;
        war += edge.hazard == Hazard::WriteAfterRead;
        waw += edge.hazard == Hazard::WriteAfterWrite;
    }
    assert(raw == 2 && war == 2 && waw == 1);
    capture.Begin({}); // Last published snapshot remains intact while recording.
    assert(capture.Latest().passes.size() == 4);
    capture.BeginPass("Imported", PassKind::Graphics);
    capture.UseResource("Persistent", Access::ReadWrite, "Read/write");
    for (uint64_t i = 1; i <= 200; ++i) capture.Descriptor(0, "Entity", i);
    capture.Publish();
    assert(capture.Latest().edges.empty()); // No same-pass self-dependency.
    assert(capture.Latest().passes[0].descriptorSets.size() == 64);
    assert(capture.Latest().passes[0].omittedDescriptorSets == 136);
    capture.Begin({}); capture.BeginPass("Cancelled", PassKind::Transfer); capture.Cancel(); capture.Publish();
    assert(capture.Latest().passes[0].name == "Imported");
    const auto example = Example();
    const auto report = example.Report();
    assert(report.find("frame slot 1/2") != std::string::npos);
    assert(report.find("swapchain image 2/3") != std::string::npos);
    assert(report.find("123456789abcdef0") != std::string::npos);
    assert(report.find("ColorAttachmentOptimal -> ShaderReadOnlyOptimal") != std::string::npos);
}

void ExportDrawData() {
    unsigned char* pixels; int width, height;
    ImGui::GetIO().Fonts->GetTexDataAsRGBA32(&pixels, &width, &height);
    std::ofstream atlas("ui-font.rgba", std::ios::binary);
    atlas.write(reinterpret_cast<char*>(pixels), width * height * 4);
    std::ofstream out("ui-draw.json");
    out << "{\"width\":1280,\"height\":800,\"atlasWidth\":" << width << ",\"atlasHeight\":" << height << ",\"lists\":[";
    auto* data = ImGui::GetDrawData();
    for (int l = 0; l < data->CmdListsCount; ++l) {
        if (l) out << ',';
        const auto* list = data->CmdLists[l];
        out << "{\"vertices\":[";
        for (int i = 0; i < list->VtxBuffer.Size; ++i) {
            if (i) out << ',';
            const auto& v = list->VtxBuffer[i];
            out << '[' << v.pos.x << ',' << v.pos.y << ',' << v.uv.x << ',' << v.uv.y << ',' << v.col << ']';
        }
        out << "],\"indices\":[";
        for (int i = 0; i < list->IdxBuffer.Size; ++i) { if (i) out << ','; out << list->IdxBuffer[i]; }
        out << "],\"commands\":[";
        for (int i = 0; i < list->CmdBuffer.Size; ++i) {
            if (i) out << ',';
            const auto& cmd = list->CmdBuffer[i];
            out << '[' << cmd.ElemCount << ',' << cmd.ClipRect.x << ',' << cmd.ClipRect.y << ',' << cmd.ClipRect.z << ',' << cmd.ClipRect.w << ']';
        }
        out << "]}";
    }
    out << "]}";
}

int main(int argc, char** argv) {
    ModelTests();
    auto graph = Example();
    ImGui::CreateContext();
    auto& io = ImGui::GetIO(); io.IniFilename = nullptr; io.DisplaySize = ImVec2(1280, 800); io.DeltaTime = 1.0f / 60.0f;
    unsigned char* pixels; int w, h; io.Fonts->GetTexDataAsRGBA32(&pixels, &w, &h);
    ViewerState state; state.open = true; state.selectedPass = "Raster composite";
    for (int frame = 0; frame < 12; ++frame) {
        if (frame == 4) { state.resourcesTab = true; state.selectedResource = "Opaque scene color"; state.selectedPass.clear(); }
        if (frame == 8) { state.resourcesTab = false; state.selectedResource.clear(); state.selectedPass = "Raster composite"; }
        ImGui::NewFrame(); DrawViewer(state, graph); ImGui::Render();
        assert(ImGui::GetDrawData() && ImGui::GetDrawData()->TotalVtxCount > 0);
    }
    if (argc > 1 && std::string_view(argv[1]) == "--export-preview") ExportDrawData();
    state.open = false;
    ImGui::NewFrame(); DrawViewer(state, graph); ImGui::Render();
    ImGui::DestroyContext();
    std::cout << "PASS: dependency hazards, merged uses, imported resources, bounded descriptors, snapshots, report, ImGui 1.60 pass/resource views\n";
}
