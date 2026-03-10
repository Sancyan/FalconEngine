#pragma once
#include <vector>
#include <queue>
#include <mutex>
// Event categories
enum class EventCategory
{
	None        = 0,
	Application = 1 << 0,
	Input       = 1 << 1,
	Keyboard    = 1 << 2,
	Mouse       = 1 << 3,
	MouseButton = 1 << 4,
	Window      = 1 << 5
};

// Enhanced event base class
class Event
{
  public:
	virtual ~Event() = default;

	virtual const char *GetType() const = 0;
	virtual Event      *Clone() const   = 0;

	// Get the categories this event belongs to
	virtual int GetCategoryFlags() const = 0;

	// Check if event is in category
	bool IsInCategory(EventCategory category) const
	{
		return GetCategoryFlags() & static_cast<int>(category);
	}
};

// Enhanced macro to define event types with categories
#define DEFINE_EVENT_TYPE_CATEGORY(type, categoryFlags) \
	static const char *GetStaticType()                  \
	{                                                   \
		return #type;                                   \
	}                                                   \
	virtual const char *GetType() const override        \
	{                                                   \
		return GetStaticType();                         \
	}                                                   \
	virtual Event *Clone() const override               \
	{                                                   \
		return new type(*this);                         \
	}                                                   \
	virtual int GetCategoryFlags() const override       \
	{                                                   \
		return categoryFlags;                           \
	}

// Event listener interface
class EventListener
{
  public:
	virtual ~EventListener()                 = default;
	virtual void OnEvent(const Event &event) = 0;
};

// Event dispatcher
class EventDispatcher
{
  private:
	const Event &event;

  public:
	explicit EventDispatcher(const Event &e) :
	    event(e)
	{}

	// Dispatch event to handler if types match
	template <typename T, typename F>
	bool Dispatch(const F &handler)
	{
		if (event.GetType() == T::GetStaticType())
		{
			handler(static_cast<const T &>(event));
			return true;
		}
		return false;
	}
};

// Event bus
class EventBus
{
  private:
	std::vector<EventListener *>       listeners;
	std::queue<std::unique_ptr<Event>> eventQueue;
	std::mutex                         queueMutex;
	bool                               immediateMode = true;

  public:
	void SetImmediateMode(bool immediate)
	{
		immediateMode = immediate;
	}

	void AddListener(EventListener *listener)
	{
		listeners.push_back(listener);
	}

	void RemoveListener(EventListener *listener)
	{
		auto it = std::find(listeners.begin(), listeners.end(), listener);
		if (it != listeners.end())
		{
			listeners.erase(it);
		}
	}

	void PublishEvent(const Event &event)
	{
		if (immediateMode)
		{
			// Dispatch event immediately
			for (auto listener : listeners)
			{
				listener->OnEvent(event);
			}
		}
		else
		{
			// Queue event for later processing
			std::lock_guard<std::mutex> lock(queueMutex);
			eventQueue.push(std::unique_ptr<Event>(event.Clone()));
		}
	}

	void ProcessEvents()
	{
		if (immediateMode)
			return;

		std::queue<std::unique_ptr<Event>> currentEvents;

		{
			std::lock_guard<std::mutex> lock(queueMutex);
			std::swap(currentEvents, eventQueue);
		}

		while (!currentEvents.empty())
		{
			auto &event = *currentEvents.front();

			for (auto listener : listeners)
			{
				listener->OnEvent(event);
			}

			currentEvents.pop();
		}
	}
};