#include "frame_graph_debug.h"
#include "imgui/imgui.h"
#include <cctype>
#include <cstdio>
#include <cstring>

namespace {
bool Matches(std::string_view value, const char* filter) {
    if (!*filter) return true;
    return std::search(value.begin(), value.end(), filter, filter + std::strlen(filter),
        [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) ==
                                  std::tolower(static_cast<unsigned char>(b)); }) != value.end();
}
ImU32 PassColor(frame_debug::PassKind kind) {
    switch (kind) {
    case frame_debug::PassKind::Compute: return IM_COL32(88, 177, 216, 255);
    case frame_debug::PassKind::Graphics: return IM_COL32(128, 190, 126, 255);
    case frame_debug::PassKind::Transfer: return IM_COL32(222, 167, 86, 255);
    default: return IM_COL32(181, 140, 217, 255);
    }
}
}

void frame_debug::DrawViewer(ViewerState& state, const Snapshot& graph) {
    if (!state.open) return;
    ImGui::SetNextWindowSize(ImVec2(1080, 720), ImGuiCond_FirstUseEver);
    if (!ImGui::Begin("Frame Graph Debugger", &state.open)) { ImGui::End(); return; }
    ImGui::Checkbox("Freeze", &state.frozen);
    ImGui::SameLine();
    if (ImGui::Button("Capture next frame")) { state.frozen = true; state.captureNext = true; }
    ImGui::SameLine();
    if (ImGui::Button("Copy report")) ImGui::SetClipboardText(graph.Report().c_str());
    ImGui::SameLine();
    ImGui::PushItemWidth(130);
    ImGui::SliderFloat("Zoom", &state.zoom, 0.65f, 1.5f, "%.2f");
    ImGui::PopItemWidth();
    if (graph.passes.empty()) {
        ImGui::TextWrapped("Waiting for a submitted frame. Capture resumes when this viewer is open and rendering is active.");
        ImGui::End(); return;
    }
    ImGui::Text("Submitted frame %llu | %s | frame slot %u / %u | swapchain image %u / %u | %u x %u",
        static_cast<unsigned long long>(graph.serial), graph.mode.c_str(), graph.frameSlot, graph.frameSlots,
        graph.swapchainImage, graph.swapchainImages, graph.width, graph.height);
    ImGui::TextDisabled("Recorded pass order; edges show inferred RAW / WAR / WAW dependencies, not GPU timings or verified synchronization.");
    ImGui::Text("%zu passes  |  %zu registered resources  |  %zu dependencies", graph.passes.size(), graph.resources.size(), graph.edges.size());

    const float step = 220.0f * state.zoom, nodeWidth = 194.0f * state.zoom, nodeHeight = 72.0f;
    if (ImGui::BeginChild("Dependency graph", ImVec2(0, 310), true, ImGuiWindowFlags_HorizontalScrollbar)) {
        const ImVec2 origin = ImGui::GetCursorScreenPos();
        const float canvasWidth = 32.0f + step * static_cast<float>(graph.passes.size());
        ImGui::Dummy(ImVec2(canvasWidth, 270));
        auto* draw = ImGui::GetWindowDrawList();
        auto position = [&](size_t i) { return ImVec2(origin.x + 16 + static_cast<float>(i) * step,
                                                    origin.y + 36 + static_cast<float>(i % 2) * 126); };
        for (const auto& edge : graph.edges) {
            const auto& resource = graph.resources[edge.resource];
            const bool highlight = !state.selectedResource.empty() ? state.selectedResource == resource.name :
                graph.passes[edge.from].name == state.selectedPass || graph.passes[edge.to].name == state.selectedPass;
            const ImVec2 from = position(edge.from), to = position(edge.to);
            const ImVec2 a(from.x + nodeWidth, from.y + nodeHeight * 0.5f);
            const ImVec2 b(to.x, to.y + nodeHeight * 0.5f);
            const ImU32 color = highlight ? IM_COL32(245, 202, 100, 255) : IM_COL32(93, 105, 123, 150);
            draw->AddBezierCurve(a, ImVec2(a.x + 30, a.y), ImVec2(b.x - 30, b.y), b, color, highlight ? 2.5f : 1.0f);
            draw->AddTriangleFilled(b, ImVec2(b.x - 7, b.y - 4), ImVec2(b.x - 7, b.y + 4), color);
        }
        for (size_t i = 0; i < graph.passes.size(); ++i) {
            const auto& pass = graph.passes[i];
            const ImVec2 p = position(i), end(p.x + nodeWidth, p.y + nodeHeight);
            const bool match = Matches(pass.name, state.filter);
            const bool selected = state.selectedPass == pass.name;
            draw->AddRectFilled(p, end, selected ? IM_COL32(54, 68, 87, 255) : IM_COL32(34, 41, 53, 255), 5);
            draw->AddRect(p, end, match ? PassColor(pass.kind) : IM_COL32(70, 75, 85, 180), 5, ~0, selected ? 2.5f : 1.0f);
            char title[96]; std::snprintf(title, sizeof(title), "%zu  %s", i, pass.name.c_str());
            std::string clipped(title);
            while (clipped.size() > 4 && ImGui::CalcTextSize(clipped.c_str()).x > nodeWidth - 16) clipped.pop_back();
            draw->PushClipRect(ImVec2(p.x + 5, p.y), ImVec2(end.x - 5, end.y), true);
            draw->AddText(ImVec2(p.x + 8, p.y + 9), IM_COL32(233, 238, 245, 255), clipped.c_str());
            char detail[96]; std::snprintf(detail, sizeof(detail), "%s | %zu resources", frame_debug::Name(pass.kind), pass.uses.size());
            draw->AddText(ImVec2(p.x + 8, p.y + 30), PassColor(pass.kind), detail);
            std::snprintf(detail, sizeof(detail), "%u draws / %u dispatches", pass.draws, pass.dispatches);
            draw->AddText(ImVec2(p.x + 8, p.y + 49), IM_COL32(168, 179, 193, 255), detail);
            draw->PopClipRect();
            ImGui::SetCursorScreenPos(p); ImGui::PushID(static_cast<int>(i));
            if (ImGui::InvisibleButton("pass", ImVec2(nodeWidth, nodeHeight))) { state.selectedPass = pass.name; state.selectedResource.clear(); }
            if (ImGui::IsItemHovered()) ImGui::SetTooltip("%s\n%s", pass.name.c_str(), pass.notes.c_str());
            ImGui::PopID();
        }
        ImGui::SetCursorScreenPos(ImVec2(origin.x, origin.y + 270));
    }
    ImGui::EndChild();

    ImGui::PushItemWidth(260); ImGui::InputText("Filter", state.filter, sizeof(state.filter)); ImGui::PopItemWidth();
    ImGui::SameLine(); if (ImGui::Button("Passes")) state.resourcesTab = false;
    ImGui::SameLine(); if (ImGui::Button("Resources")) state.resourcesTab = true;
    ImGui::Columns(2, "Frame graph details", true);
    ImGui::SetColumnWidth(0, std::max(220.0f, ImGui::GetWindowWidth() * 0.32f));
    ImGui::BeginChild("Graph list", ImVec2(0, 0), false);
    if (state.resourcesTab) {
        for (size_t i = 0; i < graph.resources.size(); ++i) {
            const auto& r = graph.resources[i];
            if (!Matches(r.name, state.filter)) continue;
            ImGui::PushID(static_cast<int>(i));
            if (ImGui::Selectable(r.name.c_str(), state.selectedResource == r.name)) { state.selectedResource = r.name; state.selectedPass.clear(); }
            ImGui::TextDisabled("%s x%u | %s", frame_debug::Name(r.scope), r.instances, r.format.c_str());
            ImGui::PopID();
        }
    } else {
        for (size_t i = 0; i < graph.passes.size(); ++i) {
            const auto& pass = graph.passes[i];
            if (!Matches(pass.name, state.filter)) continue;
            ImGui::PushID(static_cast<int>(i));
            if (ImGui::Selectable(pass.name.c_str(), state.selectedPass == pass.name)) { state.selectedPass = pass.name; state.selectedResource.clear(); }
            ImGui::TextDisabled("%s | %zu reads/writes", frame_debug::Name(pass.kind), pass.uses.size());
            ImGui::PopID();
        }
    }
    ImGui::EndChild(); ImGui::NextColumn();
    ImGui::BeginChild("Graph inspector", ImVec2(0, 0), false, ImGuiWindowFlags_HorizontalScrollbar);
    auto passIt = std::find_if(graph.passes.begin(), graph.passes.end(), [&](const auto& p) { return p.name == state.selectedPass; });
    auto resourceIt = std::find_if(graph.resources.begin(), graph.resources.end(), [&](const auto& r) { return r.name == state.selectedResource; });
    if (resourceIt != graph.resources.end()) {
        const auto& r = *resourceIt;
        const size_t index = static_cast<size_t>(resourceIt - graph.resources.begin());
        ImGui::TextUnformatted(r.name.c_str()); ImGui::Separator();
        ImGui::Text("%s | %s", r.kind.c_str(), r.format.c_str());
        ImGui::Text("Extent: %u x %u | %s x%u | selected %u", r.width, r.height, frame_debug::Name(r.scope), r.instances, r.selectedInstance);
        ImGui::Text("Handle: 0x%llx | known buffer bytes: %llu", static_cast<unsigned long long>(r.handle), static_cast<unsigned long long>(r.bytes));
        ImGui::TextWrapped("%s", r.notes.c_str());
        ImGui::Separator(); ImGui::TextUnformatted("Pass usage (select to inspect):");
        for (const auto& pass : graph.passes) for (const auto& use : pass.uses) if (use.resource == index) {
            ImGui::PushID(pass.name.c_str());
            if (ImGui::Selectable(pass.name.c_str())) { state.selectedPass = pass.name; state.selectedResource.clear(); }
            ImGui::TextWrapped("%s | %s | %s | %s", frame_debug::Name(use.access), use.usage.c_str(), use.layout.c_str(), use.binding.c_str());
            ImGui::PopID();
        }
    } else if (passIt != graph.passes.end()) {
        const auto& pass = *passIt;
        ImGui::Text("%s [%s]", pass.name.c_str(), frame_debug::Name(pass.kind));
        ImGui::TextWrapped("%s", pass.notes.c_str());
        ImGui::Text("Recorded work: %u draws / %u dispatches", pass.draws, pass.dispatches);
        ImGui::Separator(); ImGui::TextUnformatted("Pipelines:");
        for (const auto& p : pass.pipelines) ImGui::Text("%s | 0x%llx", p.name.c_str(), static_cast<unsigned long long>(p.handle));
        ImGui::TextUnformatted("Descriptor sets (unique samples, up to 64):");
        for (const auto& set : pass.descriptorSets) ImGui::Text("Set %u: %s | 0x%llx", set.set, set.name.c_str(), static_cast<unsigned long long>(set.handle));
        if (pass.omittedDescriptorSets) ImGui::TextDisabled("%u additional descriptor bindings not expanded", pass.omittedDescriptorSets);
        ImGui::Separator(); ImGui::TextUnformatted("Resources (select to follow):");
        for (const auto& use : pass.uses) {
            const auto& r = graph.resources[use.resource];
            ImGui::PushID(static_cast<int>(use.resource));
            if (ImGui::Selectable(r.name.c_str())) { state.selectedResource = r.name; state.selectedPass.clear(); }
            ImGui::TextWrapped("%s | %s | layout: %s | %s", frame_debug::Name(use.access), use.usage.c_str(), use.layout.c_str(), use.binding.c_str());
            ImGui::PopID();
        }
        if (!pass.barriers.empty()) { ImGui::Separator(); ImGui::TextUnformatted("Recorded image barriers:"); }
        for (const auto& b : pass.barriers) {
            ImGui::Text("%s: %s -> %s", graph.resources[b.resource].name.c_str(), b.before.c_str(), b.after.c_str());
            ImGui::TextWrapped("%s -> %s", b.source.c_str(), b.destination.c_str());
        }
    } else {
        ImGui::TextWrapped("Select a pass or resource. Persistent resources may be read without a producer in this frame. Resource counts describe registered banks; upload jobs, memory pools and individual scene meshes are not expanded.");
    }
    ImGui::EndChild(); ImGui::Columns(1);
    ImGui::End();
}
