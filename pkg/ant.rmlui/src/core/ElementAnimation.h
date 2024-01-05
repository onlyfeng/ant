#pragma once

#include <css/Property.h>
#include <css/PropertyRaw.h>
#include <core/Tween.h>
#include <core/ID.h>
#include <css/StyleSheet.h>

namespace Rml {

class ElementInterpolate {
public:
	ElementInterpolate(Element& element, const Property& in_prop, const Property& out_prop);
	ElementInterpolate(Element& element, const PropertyRaw& in_prop, const PropertyRaw& out_prop);
	Property Update(float t0, float t1, float t, const Tween& tween);
private:
	Property p0;
	Property p1;
};

class ElementTransition {
public:
	ElementTransition(Element& element, const Transition& transition, const PropertyRaw& in_prop, const PropertyRaw& out_prop);
	Property UpdateProperty(float delta);
	bool IsComplete() const { return complete; }
	float GetTime() const { return time; }
private:
	Transition transition;
	ElementInterpolate interpolate;
	float time;
	bool complete;
};

class ElementAnimation {
public:
	ElementAnimation(Element& element, const Animation& animation, const Keyframe& keyframe);
	Property UpdateProperty(Element& element, float delta);
	const std::string& GetName() const { return animation.name; }
	bool IsComplete() const { return complete; }
	float GetTime() const { return time; }
private:
	const Animation animation;
	const Keyframe& keyframe;
	ElementInterpolate interpolate;
	float time;
	int current_iteration;
	uint8_t key;
	bool complete;
	bool reverse_direction;
};

}
