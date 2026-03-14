#pragma once
#include <math.h>
#include <string>
#include <functional>
#include <vulkan/vulkan_raii.hpp>
#include "resource_manager.h"

class RenderGraph
{
  private:

	  struct ImageResource
	  {
		  std::string name;
		  vk::Format  format;
		  vk::Extent2D extent;
		  vk::ImageUsageFlags usage;
		  vk::ImageLayout     initialLayout;
		  vk::ImageLayout     finalLayout;

		  vk::raii::Image image = nullptr;
		  vk::raii::DeviceMemory memory = nullptr;
		  vk::raii::ImageView    view   = nullptr;
	  };

	  struct Pass
	  {
		  std::string name;
		  std::vector<std::string> inputs;
		  std::vector<std::string> outputs;
		  std::function<void(vk::raii::CommandBuffer &)> executeFunc;
		  
	  };

	  std::unordered_map<std::string, ImageResource> resources;
	  std::vector<Pass>                         passes;
	  std::vector<size_t>                       executionOrder;

	  std::vector<vk::raii::Semaphore> semaphores;
	  std::vector<std::pair<size_t, size_t>> semaphoreSignalWaitPairs;

	  vk::raii::Device &device;

	  public:
	  explicit RenderGraph(vk::raii::Device &dev) :
	      device(dev) {};

      // Resource registration interface for declaring all resources used during rendering
	  // This method establishes resource metadata without creating actual GPU resources
	  void AddResource(const std::string &name, vk::Format format, vk::Extent2D extent,
	                   vk::ImageUsageFlags usage, vk::ImageLayout initialLayout,
	                   vk::ImageLayout finalLayout)
	  {
		  ImageResource resource;
		  resource.name          = name;                 // Store human-readable identifier
		  resource.format        = format;               // Define pixel format and bit depth
		  resource.extent        = extent;               // Set resource dimensions
		  resource.usage         = usage;                // Specify intended usage patterns
		  resource.initialLayout = initialLayout;        // Define starting layout state
		  resource.finalLayout   = finalLayout;          // Define required ending state

		  resources.insert_or_assign(name, resource);        // Register in the global resource map
	  }

	      // Pass registration interface for defining rendering operations and their dependencies
	  // This method establishes the logical structure of rendering without immediate execution
	  void AddPass(const std::string                             &name,
	               const std::vector<std::string>                &inputs,
	               const std::vector<std::string>                &outputs,
	               std::function<void(vk::raii::CommandBuffer &)> executeFunc)
	  {
		  Pass pass;
		  pass.name        = name;               // Assign descriptive identifier
		  pass.inputs      = inputs;             // List all resources this pass reads
		  pass.outputs     = outputs;            // List all resources this pass writes
		  pass.executeFunc = executeFunc;        // Store the actual rendering implementation

		  passes.push_back(pass);        // Add to the ordered pass list
	  }

	  void Compile()
	  {
		  //DAG graph construction
		  std::vector<std::vector<size_t>> dependencies(passes.size());
		  std::vector<std::vector<size_t>> dependents(passes.size());

		  //Track which pass produces each resource (write-after-write dependencies)
		  std::unordered_map<std::string, size_t> resourceWriters;


		  // Dependency Discovery Through Resource Usage Analysis
		  // Analyze each pass to determine data flow relationships
		  for (size_t i = 0; i < passes.size(); ++i) {
			  const auto &pass = passes[i];

			  // Process input dependencies - this pass must wait for producers
			  for (const auto &input : pass.inputs)
			  {
				  auto it = resourceWriters.find(input);
				  if (it != resourceWriters.end())
				  {
					  // Found the pass that produces this input - create dependency link
					  dependencies[i].push_back(it->second); // This pass depends on the producer
					  dependents[it->second].push_back(i);          // Producer has this as dependent
					
				  }
			  
			  }

			  // Register output production - subsequent passes may depend on these
			  for (const auto& output : pass.outputs) {
				  resourceWriters[output] = i;
			  }
		  }

		  //Topological Sort for Optimal exe order
		  //Depth first search
		  std::vector<bool> visited(passes.size(), false);
		  std::vector<bool> inStack(passes.size(), false);

		  std::function<void(size_t)> visit = [&](size_t node) {
			  if (inStack[node])
			  {
				  // Cycle Detected
				  throw std::runtime_error("Cycle found in Render Graph");
			  }

			  if (visited[node])
			  {
				  return; //Node has already been processed
			  }

			  inStack[node] = true; 

			  for (auto dependent : dependents[node]) {
				  visit(dependent);
			  }

			  inStack[node] = false;
			  visited[node] = true;
			  executionOrder.push_back(node);
		  };

		  for (size_t i = 0; i < passes.size(); ++i)
		  {
			  if (!visited[i]) {
				  visit(i);
			  }
		  
		  }

			// Automatic Synchronization Object Creation
		  // Generate semaphores for all dependencies identified during analysis
		  for (size_t i = 0; i < passes.size(); ++i)
		  {
			  for (auto dep : dependencies[i])
			  {
				  // Create a GPU semaphore for this dependency relationship
				  // The dependent pass will wait on this semaphore before executing
				  semaphores.emplace_back(device.createSemaphore({}));
				  semaphoreSignalWaitPairs.emplace_back(dep, i);        // (producer, consumer) pair
			  }
		  }

        // Physical Resource Allocation and Creation
		  // Transform resource descriptions into actual GPU objects
		  for (auto &[name, resource] : resources)
		  {
			  // Configure image creation parameters based on resource description
			  vk::ImageCreateInfo imageInfo;
			  imageInfo.setImageType(vk::ImageType::e2D)                                // 2D texture/render target
			      .setFormat(resource.format)                                           // Pixel format from description
			      .setExtent({resource.extent.width, resource.extent.height, 1})        // Dimensions
			      .setMipLevels(1)                                                      // Single mip level for simplicity
			      .setArrayLayers(1)                                                    // Single layer (not array texture)
			      .setSamples(vk::SampleCountFlagBits::e1)                              // No multisampling
			      .setTiling(vk::ImageTiling::eOptimal)                                 // GPU-optimal memory layout
			      .setUsage(resource.usage)                                             // Usage flags from registration
			      .setSharingMode(vk::SharingMode::eExclusive)                          // Single queue family access
			      .setInitialLayout(vk::ImageLayout::eUndefined);                       // Initial layout (will be transitioned)

			  resource.image = device.createImage(imageInfo);        // Create the GPU image object

			  // Allocate backing memory for the image
			  vk::MemoryRequirements memRequirements = resource.image.getMemoryRequirements();

			  vk::MemoryAllocateInfo allocInfo;
			  allocInfo.setAllocationSize(memRequirements.size)        // Required memory size
			      .setMemoryTypeIndex(FindMemoryType(memRequirements.memoryTypeBits,
			                                         vk::MemoryPropertyFlagBits::eDeviceLocal));        // GPU-local memory

			  resource.memory = device.allocateMemory(allocInfo);        // Allocate GPU memory
			  resource.image.bindMemory(*resource.memory, 0);            // Bind memory to image

			  // Create image view for shader access
			  vk::ImageViewCreateInfo viewInfo;
			  viewInfo.setImage(*resource.image)                                              // Reference the created image
			      .setViewType(vk::ImageViewType::e2D)                                        // 2D view type
			      .setFormat(resource.format)                                                 // Match image format
			      .setSubresourceRange({vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1});        // Full image access

			  resource.view = device.createImageView(viewInfo);        // Create shader-accessible view
		  }

	  }

	  ImageResource* GetResource(const std::string& name)
	  {
		  auto it = resources.find(name);
		  return (it != resources.end()) ? &it->second : nullptr;
	  }

	      // Rendergraph execution engine - coordinates pass execution with automatic synchronization
	  // This method transforms the compiled rendergraph into actual GPU work
	  void Execute(vk::raii::CommandBuffer &commandBuffer, vk::Queue queue)
	  {
		  // Execution state management for dynamic synchronization
		  std::vector<vk::CommandBuffer>      cmdBuffers;              // Command buffer storage
		  std::vector<vk::Semaphore>          waitSemaphores;          // Synchronization dependencies for current pass
		  std::vector<vk::PipelineStageFlags> waitStages;              // Pipeline stages to wait on
		  std::vector<vk::Semaphore>          signalSemaphores;        // Semaphores to signal after current pass

		  // Ordered Pass Execution with Automatic Dependency Management
		  // Execute each pass in the computed dependency-safe order
		  for (auto passIdx : executionOrder)
		  {
			  const auto &pass = passes[passIdx];

			  // Synchronization Setup - Collect Dependencies for Current Pass
			  // Determine what this pass must wait for before executing
			  waitSemaphores.clear();
			  waitStages.clear();

			  for (size_t i = 0; i < semaphoreSignalWaitPairs.size(); ++i)
			  {
				  if (semaphoreSignalWaitPairs[i].second == passIdx)
				  {
					  // This pass depends on the completion of another pass
					  waitSemaphores.push_back(*semaphores[i]);                                       // Wait for dependency completion
					  waitStages.push_back(vk::PipelineStageFlagBits::eColorAttachmentOutput);        // Wait at output stage
				  }
			  }

			  // Collect semaphores that this pass will signal for dependent passes
			  signalSemaphores.clear();
			  for (size_t i = 0; i < semaphoreSignalWaitPairs.size(); ++i)
			  {
				  if (semaphoreSignalWaitPairs[i].first == passIdx)
				  {
					  // Other passes depend on this pass's completion
					  signalSemaphores.push_back(*semaphores[i]);        // Signal completion for dependents
				  }
			  }

			  // Command Buffer Preparation and Resource Layout Transitions
			  // Set up command recording and transition resources to appropriate layouts
			  commandBuffer.begin({});        // Begin command recording

			  // Transition input resources to shader-readable layouts
			  for (const auto &input : pass.inputs)
			  {
				  auto &resource = resources[input];

				  vk::ImageMemoryBarrier barrier;
				  barrier.setOldLayout(resource.initialLayout)                      // Current resource layout
				      .setNewLayout(vk::ImageLayout::eShaderReadOnlyOptimal)        // Target layout for reading
				      .setSrcQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)              // No queue family transfer
				      .setDstQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
				      .setImage(*resource.image)                                                 // Target image
				      .setSubresourceRange({vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1})        // Full image range
				      .setSrcAccessMask(vk::AccessFlagBits::eMemoryWrite)                        // Previous write access
				      .setDstAccessMask(vk::AccessFlagBits::eShaderRead);                        // Required read access

				  // Insert pipeline barrier for safe layout transition
				  commandBuffer.pipelineBarrier(
				      vk::PipelineStageFlagBits::eAllCommands,           // Wait for all previous work
				      vk::PipelineStageFlagBits::eFragmentShader,        // Enable fragment shader access
				      vk::DependencyFlagBits::eByRegion,                 // Region-local dependency
				      0, nullptr, 0, nullptr, 1, &barrier                // Image barrier only
				  );
			  }

			  // Transition output resources to render target layouts
			  for (const auto &output : pass.outputs)
			  {
				  auto &resource = resources[output];

				  vk::ImageMemoryBarrier barrier;
				  barrier.setOldLayout(resource.initialLayout)                       // Current layout state
				      .setNewLayout(vk::ImageLayout::eColorAttachmentOptimal)        // Optimal for color output
				      .setSrcQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
				      .setDstQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
				      .setImage(*resource.image)
				      .setSubresourceRange({vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1})
				      .setSrcAccessMask(vk::AccessFlagBits::eMemoryRead)                   // Previous read access
				      .setDstAccessMask(vk::AccessFlagBits::eColorAttachmentWrite);        // Required write access

				  // Insert barrier for safe transition to writable state
				  commandBuffer.pipelineBarrier(
				      vk::PipelineStageFlagBits::eAllCommands,
				      vk::PipelineStageFlagBits::eColorAttachmentOutput,        // Enable color attachment writes
				      vk::DependencyFlagBits::eByRegion,
				      0, nullptr, 0, nullptr, 1, &barrier);
			  }

			  // Pass Execution - Execute the Actual Rendering Logic
			  // Call the user-provided rendering function with prepared command buffer
			  pass.executeFunc(commandBuffer);        // Execute pass-specific rendering

			  // Final Layout Transitions - Prepare Resources for Subsequent Use
			  // Transition output resources to their final required layouts
			  for (const auto &output : pass.outputs)
			  {
				  auto &resource = resources[output];

				  vk::ImageMemoryBarrier barrier;
				  barrier.setOldLayout(vk::ImageLayout::eColorAttachmentOptimal)        // Current writable layout
				      .setNewLayout(resource.finalLayout)                               // Required final layout
				      .setSrcQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
				      .setDstQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
				      .setImage(*resource.image)
				      .setSubresourceRange({vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1})
				      .setSrcAccessMask(vk::AccessFlagBits::eColorAttachmentWrite)        // Previous write operations
				      .setDstAccessMask(vk::AccessFlagBits::eMemoryRead);                 // Enable subsequent reads

				  // Insert final barrier for layout transition
				  commandBuffer.pipelineBarrier(
				      vk::PipelineStageFlagBits::eColorAttachmentOutput,        // After color writes complete
				      vk::PipelineStageFlagBits::eAllCommands,                  // Before any subsequent work
				      vk::DependencyFlagBits::eByRegion,
				      0, nullptr, 0, nullptr, 1, &barrier);
			  }

			  // Command Submission with Synchronization
			  // Submit command buffer with appropriate dependency and signaling semaphores
			  commandBuffer.end();        // Finalize command recording

			  vk::SubmitInfo submitInfo;
			  submitInfo.setWaitSemaphoreCount(static_cast<uint32_t>(waitSemaphores.size()))        // Dependencies to wait for
			      .setPWaitSemaphores(waitSemaphores.data())                                        // Dependency semaphores
			      .setPWaitDstStageMask(waitStages.data())                                          // Pipeline stages to wait at
			      .setCommandBufferCount(1)                                                         // Single command buffer
			      .setPCommandBuffers(&*commandBuffer)                                              // Command buffer to execute
			      .setSignalSemaphoreCount(static_cast<uint32_t>(signalSemaphores.size()))          // Semaphores to signal
			      .setPSignalSemaphores(signalSemaphores.data());                                   // Signal semaphores

			  queue.submit(1, &submitInfo, nullptr);        // Submit to GPU queue
		  }
	  }

	  

	  private:
	  uint32_t FindMemoryType(uint32_t typeFilter, vk::MemoryPropertyFlags properties)
	  {
		  // Implementation to find suitable memory type
		  // TODO: ...
		  return 0;        // Placeholder
	  }

};
