#pragma once
#include "frame_graph_debug.h"
#include <type_traits>
#include <vulkan/vulkan.hpp>

template <typename Handle>
uint64_t FrameGraphDebugHandle(Handle handle) {
    using Raw = typename Handle::CType;
    if constexpr (std::is_pointer_v<Raw>)
        return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(static_cast<Raw>(handle)));
    else
        return static_cast<uint64_t>(static_cast<Raw>(handle));
}

inline void FrameGraphDebugBarrier(frame_debug::Capture& capture, const char* resource,
                                   const vk::ImageMemoryBarrier2& barrier) {
    if (!capture.Active()) return;
    capture.Transition(resource, vk::to_string(barrier.oldLayout), vk::to_string(barrier.newLayout),
                       vk::to_string(barrier.srcStageMask) + " / " + vk::to_string(barrier.srcAccessMask),
                       vk::to_string(barrier.dstStageMask) + " / " + vk::to_string(barrier.dstAccessMask));
}
