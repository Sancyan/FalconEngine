#pragma once
#include "camera_component.h"
#include "mesh_component.h"
#include "renderer.h"



class CullingSystem {
  private:
	Camera *camera;
	std::vector<Entity*> visibleEntities;

	public:
	explicit CullingSystem(Camera *cam) : camera(cam) {}

	void SetCamera(Camera* cam)
	{
		camera = cam;
	}

	void CullScene(const std::vector<Entity*>& allEntities)
	{
		visibleEntities.clear();

		if (!camera)
			return;


		//TODO:ADD Frustrum to camera obj
		Frustum frustum = camera->GetFrustum();

		for (auto entity : allEntities)
		{
			if (!entity->IsActive())
				continue;

			auto meshComponent = entity->GetComponent<MeshComponent>();

			if (!meshComponent)
				continue;

			auto transformComponent = entity->GetComponent<TransformComponent>();

			if (!transformComponent)
				continue;

			//TODO: ADD boundingbox to mesh component
			BoundingBox boundingBox = meshComponent->GetBoundingBox();

			//TODO: ADD transform comp get transform matrix
			boundingBox.Transform(transformComponent->getTranformMatrix());


			//TODO: ADD frustum intersects logic
			if (frustum.Intersects(boundingBox))
			{
				visibleEntities.push_back(entity);
			}
		}
	}

	const std::vector<Entity *> &GetVisibleEntities() const
	{
		return visibleEntities;
	}
};