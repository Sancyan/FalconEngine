#pragma once
#include <math.h>
#include <string>
#include <functional>
#include <vulkan/vulkan.hpp>
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


	  }

};
