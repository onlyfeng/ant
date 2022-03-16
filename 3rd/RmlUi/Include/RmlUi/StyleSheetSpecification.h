#pragma once

#include "Types.h"

namespace Rml {

class PropertyParser;
class PropertyDefinition;

class StyleSheetSpecification {
public:
	static bool Initialise();
	static void Shutdown();
	static PropertyParser* GetParser(const std::string& parser_name);
	static const PropertyDefinition* GetPropertyDefinition(PropertyId id);
	static const PropertyIdSet& GetRegisteredInheritedProperties();
	static bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name);
	static bool ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value);
};

}
