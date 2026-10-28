#pragma once

#include <algorithm>
#include <cstdint>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

// Non-owning descriptions of commands recorded by the active renderer. This
// does not schedule work, retain Vulkan objects, or imply GPU completion.
namespace frame_debug {
enum class Access { Read, Write, ReadWrite };
enum class PassKind { Graphics, Compute, Transfer, Present };
enum class Scope { Shared, FrameSlot, Swapchain, External };
enum class Hazard { ReadAfterWrite, WriteAfterRead, WriteAfterWrite };

inline const char* Name(Access value) {
    return value == Access::Read ? "Read" : value == Access::Write ? "Write" : "Read/write";
}
inline const char* Name(PassKind value) {
    switch (value) {
    case PassKind::Graphics: return "Graphics";
    case PassKind::Compute: return "Compute";
    case PassKind::Transfer: return "Transfer";
    default: return "Present";
    }
}
inline const char* Name(Scope value) {
    switch (value) {
    case Scope::FrameSlot: return "Per frame slot";
    case Scope::Swapchain: return "Per swapchain image";
    case Scope::Shared: return "Shared";
    default: return "External / aggregate";
    }
}
inline const char* Name(Hazard value) {
    return value == Hazard::ReadAfterWrite ? "RAW" : value == Hazard::WriteAfterRead ? "WAR" : "WAW";
}

struct Resource {
    std::string name;
    std::string kind = "Image";
    std::string format;
    uint32_t width = 0, height = 0;
    Scope scope = Scope::External;
    uint32_t instances = 0;
    uint32_t selectedInstance = 0;
    uint64_t handle = 0;
    uint64_t bytes = 0; // Known buffer capacity, not a Vulkan allocation estimate.
    std::string notes;
};
struct Use {
    size_t resource = 0;
    Access access = Access::Read;
    std::string usage;
    std::string layout;
    std::string binding;
};
struct NamedHandle {
    std::string name;
    uint64_t handle = 0;
    uint32_t set = 0;
};
struct Barrier {
    size_t resource = 0;
    std::string before, after, source, destination;
};
struct Pass {
    std::string name;
    PassKind kind = PassKind::Graphics;
    std::string notes;
    std::vector<Use> uses;
    std::vector<NamedHandle> pipelines;
    std::vector<NamedHandle> descriptorSets;
    std::vector<Barrier> barriers;
    uint32_t draws = 0, dispatches = 0;
    uint32_t omittedDescriptorSets = 0;
};
struct Edge {
    size_t from = 0, to = 0, resource = 0;
    Hazard hazard = Hazard::ReadAfterWrite;
};
struct Snapshot {
    uint64_t serial = 0;
    uint32_t frameSlot = 0, frameSlots = 0, swapchainImage = 0, swapchainImages = 0;
    uint32_t width = 0, height = 0;
    std::string mode;
    std::vector<Resource> resources;
    std::vector<Pass> passes;
    std::vector<Edge> edges;

    void BuildEdges() {
        edges.clear();
        const size_t none = static_cast<size_t>(-1);
        std::vector<size_t> writers(resources.size(), none);
        std::vector<std::vector<size_t>> readers(resources.size());
        for (size_t p = 0; p < passes.size(); ++p) {
            for (const auto& use : passes[p].uses) {
                const size_t r = use.resource;
                if (r >= resources.size()) continue;
                if (use.access != Access::Write && writers[r] != none && writers[r] != p)
                    edges.push_back({writers[r], p, r, Hazard::ReadAfterWrite});
                if (use.access != Access::Read) {
                    if (writers[r] != none && writers[r] != p)
                        edges.push_back({writers[r], p, r, Hazard::WriteAfterWrite});
                    for (const size_t reader : readers[r])
                        if (reader != p) edges.push_back({reader, p, r, Hazard::WriteAfterRead});
                    readers[r].clear();
                    writers[r] = p;
                } else if (std::find(readers[r].begin(), readers[r].end(), p) == readers[r].end()) {
                    readers[r].push_back(p);
                }
            }
        }
    }

    std::string Report() const {
        std::ostringstream out;
        out << "Frame graph: " << mode << " | submitted frame " << serial
            << " | frame slot " << frameSlot << '/' << frameSlots
            << " | swapchain image " << swapchainImage << '/' << swapchainImages << '\n';
        out << "Recorded command order; dependencies inferred from annotated uses. No GPU timings.\n";
        for (size_t p = 0; p < passes.size(); ++p) {
            const auto& pass = passes[p];
            out << p << ": " << pass.name << " [" << Name(pass.kind) << "] draws=" << pass.draws
                << " dispatches=" << pass.dispatches << '\n';
            for (const auto& pipeline : pass.pipelines)
                out << "  pipeline " << pipeline.name << " 0x" << std::hex << pipeline.handle << std::dec << '\n';
            for (const auto& set : pass.descriptorSets)
                out << "  set " << set.set << ": " << set.name << " 0x" << std::hex << set.handle << std::dec << '\n';
            if (pass.omittedDescriptorSets) out << "  additional descriptor samples omitted: " << pass.omittedDescriptorSets << '\n';
            for (const auto& use : pass.uses) {
                const auto& r = resources[use.resource];
                out << "  " << Name(use.access) << ' ' << r.name << " | " << use.usage
                    << " | " << use.layout << " | " << use.binding << '\n';
            }
            for (const auto& b : pass.barriers)
                out << "  barrier " << resources[b.resource].name << ": " << b.before << " -> " << b.after
                    << " | " << b.source << " -> " << b.destination << '\n';
        }
        out << "Resources (counts describe registered resource banks, not all device allocations):\n";
        for (const auto& r : resources) {
            out << "  " << r.name << " | " << r.kind << " | " << r.format << " | " << r.width << 'x' << r.height
                << " | " << Name(r.scope) << " x" << r.instances << " selected=" << r.selectedInstance
                << " | handle=0x" << std::hex << r.handle << std::dec << " | bytes=" << r.bytes << '\n';
            if (!r.notes.empty()) out << "    " << r.notes << '\n';
        }
        for (const auto& edge : edges)
            out << "  dependency " << edge.from << " -> " << edge.to << " | " << resources[edge.resource].name
                << " | " << Name(edge.hazard) << '\n';
        return out.str();
    }
};

class Capture {
public:
    bool Active() const { return active; }
    const Snapshot& Latest() const { return latest; }
    void Begin(Snapshot metadata) {
        recording = std::move(metadata);
        currentPass = static_cast<size_t>(-1);
        active = true;
    }
    void Cancel() { active = false; }
    void Publish() {
        if (!active) return;
        recording.BuildEdges();
        std::swap(latest, recording);
        active = false;
    }
    void AddResource(Resource resource) {
        if (!active) return;
        const size_t index = FindResource(resource.name);
        if (index == recording.resources.size()) recording.resources.push_back(std::move(resource));
        else recording.resources[index] = std::move(resource);
    }
    void BeginPass(std::string_view name, PassKind kind, std::string_view notes = {}) {
        if (!active) return;
        recording.passes.push_back({std::string(name), kind, std::string(notes)});
        currentPass = recording.passes.size() - 1;
    }
    void UseResource(std::string_view name, Access access, std::string_view usage,
                     std::string_view layout = {}, std::string_view binding = {}) {
        if (!HasPass()) return;
        const size_t resource = EnsureResource(name);
        auto& uses = recording.passes[currentPass].uses;
        auto found = std::find_if(uses.begin(), uses.end(), [resource](const Use& u) { return u.resource == resource; });
        if (found == uses.end()) uses.push_back({resource, access, std::string(usage), std::string(layout), std::string(binding)});
        else {
            if (found->access != access) found->access = Access::ReadWrite;
            if (found->usage.find(usage) == std::string::npos) found->usage += "; " + std::string(usage);
            if (!layout.empty()) found->layout = layout;
            if (!binding.empty() && found->binding.find(binding) == std::string::npos)
                found->binding += (found->binding.empty() ? "" : "; ") + std::string(binding);
        }
    }
    void Pipeline(std::string_view name, uint64_t handle) {
        if (!HasPass() || !handle) return;
        auto& pipelines = recording.passes[currentPass].pipelines;
        if (std::none_of(pipelines.begin(), pipelines.end(), [handle](const NamedHandle& p) { return p.handle == handle; }))
            pipelines.push_back({std::string(name), handle, 0});
    }
    void Descriptor(uint32_t set, std::string_view name, uint64_t handle) {
        if (!HasPass() || !handle) return;
        auto& pass = recording.passes[currentPass];
        if (std::any_of(pass.descriptorSets.begin(), pass.descriptorSets.end(), [=](const NamedHandle& d) {
                return d.set == set && d.handle == handle;
            })) return;
        // Large scenes bind thousands of entity sets. Keep the debug capture bounded.
        if (pass.descriptorSets.size() >= 64) { ++pass.omittedDescriptorSets; return; }
        pass.descriptorSets.push_back({std::string(name), handle, set});
    }
    void Transition(std::string_view resource, std::string_view before, std::string_view after,
                    std::string_view source, std::string_view destination) {
        if (!HasPass()) return;
        const size_t index = EnsureResource(resource);
        recording.passes[currentPass].barriers.push_back({index, std::string(before), std::string(after),
                                                        std::string(source), std::string(destination)});
    }
    void Draw(uint32_t count = 1) { if (HasPass()) recording.passes[currentPass].draws += count; }
    void Dispatch() { if (HasPass()) ++recording.passes[currentPass].dispatches; }
private:
    bool HasPass() const { return active && currentPass < recording.passes.size(); }
    size_t FindResource(std::string_view name) const {
        const auto it = std::find_if(recording.resources.begin(), recording.resources.end(),
                                     [name](const Resource& r) { return r.name == name; });
        return static_cast<size_t>(it - recording.resources.begin());
    }
    size_t EnsureResource(std::string_view name) {
        const size_t index = FindResource(name);
        if (index == recording.resources.size()) {
            Resource resource;
            resource.name = name;
            resource.kind = "External / aggregate";
            recording.resources.push_back(std::move(resource));
        }
        return index;
    }
    bool active = false;
    size_t currentPass = static_cast<size_t>(-1);
    Snapshot recording, latest;
};

struct ViewerState {
    bool open = false;
    bool frozen = false;
    bool captureNext = false;
    bool singleCapture = false;
    bool resourcesTab = false;
    float zoom = 1.0f;
    char filter[128]{};
    std::string selectedPass;
    std::string selectedResource;
};
void DrawViewer(ViewerState& state, const Snapshot& graph);
} // namespace frame_debug
