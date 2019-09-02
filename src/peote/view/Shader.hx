package peote.view;

class Shader 
{
	// ----------------------------------------------------------------------------------
	// -------------------------- VERTEX SHADER TEMPLATE --------------------------------	
	// ----------------------------------------------------------------------------------

	@:allow(peote.view) static var vertexShader(default, null):String =		
	"
	::if isES3::#version 300 es::end::
	::if VERTEX_INT_PRECISION::precision ::VERTEX_INT_PRECISION:: int; ::end::
	::if VERTEX_FLOAT_PRECISION::precision ::VERTEX_FLOAT_PRECISION:: float; ::end::
	::if VERTEX_SAMPLER_PRECISION::precision ::VERTEX_SAMPLER_PRECISION:: sampler2D; ::end::
	
	// Uniforms -------------------------
	::if (!isPICKING && isUBO)::
	//layout(std140) uniform uboView
	uniform uboView
	{
		vec2 uResolution;
		vec2 uViewOffset;
		vec2 uViewZoom;
	};
	//layout(std140) uniform uboDisplay
	uniform uboDisplay
	{
		vec2 uOffset;
		vec2 uZoom;
	};
	::else::
	uniform vec2 uResolution;
	uniform vec2 uOffset;
	uniform vec2 uZoom;
	::end::
	
	::UNIFORM_TIME::
	
	// Attributes -------------------------
	::IN:: vec2 aPosition;
	
	::if isPICKING::
		::if !isINSTANCED::
			::IN:: vec4 aElement;
		::end::
	::end::
	
	::ATTRIB_POS::
	::ATTRIB_SIZE::
	::ATTRIB_TIME::
	::ATTRIB_ROTZ::
	::ATTRIB_PIVOT::
	
	::ATTRIB_COLOR::
	
	::ATTRIB_PACK::
	
	// Varyings ---------------------------
	::if isPICKING::
		::if isINSTANCED::
			flat ::VAROUT:: int vElement;
		::else::
			::VAROUT:: vec4 vElement;
		::end::
	::end::
	
	::OUT_COLOR::
	::OUT_VARYING::
	
	::if hasTEXTURES::
		::OUT_TEXCOORD::
		::OUT_TEXVARYING::
	::end::

	// custom functions -------------------
	::VERTEX_INJECTION::

	// --------- vertex main --------------
	void main(void)
	{
		::CALC_TIME::
		::CALC_SIZE::
		::CALC_PIVOT::		
		::CALC_ROTZ::
		::CALC_POS::
		::CALC_COLOR::

		::CALC_VARYING::

		::if hasTEXTURES::
			::CALC_TEXCOORD::			
			::CALC_TEXVARYING::
		::end::
		
		::if isPICKING::
			::if isINSTANCED::
				vElement = gl_InstanceID + 1;
			::else::
				vElement = aElement;
			::end::
		::end::
		
		float width = uResolution.x;
		float height = uResolution.y;
		::if (!isPICKING && isUBO)::
		float deltaX = (uOffset.x  + uViewOffset.x) / uZoom.x;
		float deltaY = (uOffset.y  + uViewOffset.y) / uZoom.y;
		vec2 zoom = uZoom * uViewZoom;
		::else::
		float deltaX = uOffset.x;
		float deltaY = uOffset.y;
		vec2 zoom = uZoom;
		::end::
		
		gl_Position = mat4 (
			vec4(2.0/width*zoom.x,                 0.0,  0.0, 0.0),
			vec4(             0.0,  -2.0/height*zoom.y,  0.0, 0.0),
			vec4(0.0             ,                 0.0, -1.0, 0.0),
			vec4(2.0 * deltaX * zoom.x / width - 1.0, 1.0 - 2.0 * deltaY * zoom.y / height, 0.0, 1.0)
		)
		* vec4 (
			::if isPIXELSNAPPING::
			floor( pos * ::PIXELDIVISOR:: * zoom ) / ::PIXELDIVISOR:: / zoom
			::else::
				pos
			::end::
			, ::ZINDEX::
			, 1.0
		);
	}
	";
	
	// ----------------------------------------------------------------------------------
	// ------------------------ FRAGMENT SHADER TEMPLATE --------------------------------
	// ----------------------------------------------------------------------------------
	
	@:allow(peote.view) static var fragmentShader(default, null):String =	
	"
	::if isES3::#version 300 es::end::
	::foreach FRAGMENT_EXTENSIONS::#extension ::EXTENSION:: : enable::end::
	
	::if FRAGMENT_INT_PRECISION::precision ::FRAGMENT_INT_PRECISION:: int; ::end::
	::if FRAGMENT_FLOAT_PRECISION::precision ::FRAGMENT_FLOAT_PRECISION:: float; ::end::
	::if FRAGMENT_SAMPLER_PRECISION::precision ::FRAGMENT_SAMPLER_PRECISION:: sampler2D; ::end::
	
	// Uniforms ------------------------- TODO: let is enable/disable
	::if (!isPICKING && isUBO)::
	//layout(std140) uniform uboView
	uniform uboView
	{
		vec2 uResolution;
		vec2 uViewOffset;
		vec2 uViewZoom;
	};
	//layout(std140) uniform uboDisplay
	uniform uboDisplay
	{
		vec2 uOffset;
		vec2 uZoom;
	};
	::else::
	uniform vec2 uResolution;
	uniform vec2 uOffset;
	uniform vec2 uZoom;
	::end::
	//  -------------------------
	
	::FRAGMENT_PROGRAM_UNIFORMS::
	
	// Varyings ---------------------------
	::if isPICKING::
		::if isINSTANCED::
			flat ::VARIN:: int vElement;
		::else::
			::VARIN:: vec4 vElement;
		::end::
	::end::

	::IN_COLOR::
	::IN_VARYING::
			
	::if hasTEXTURES::
		::IN_TEXCOORD::
		::IN_TEXVARYING::
	::end::
	
	
	::if isES3::
		::if (isPICKING && isINSTANCED)::
			out int Color;
		::else::
			out vec4 Color;
		::end::
	::end::

	// custom functions -------------------
	::FRAGMENT_INJECTION::
	
	// --------- fragment main ------------
	void main(void)
	{	
		::FRAGMENT_CALC_COLOR::
		
		::if hasTEXTURES::
			::foreach TEXTURES::
				// ------------- LAYER ::LAYER:: --------------
				::foreach ELEMENT_LAYERS::
				::if_ELEMENT_LAYER::
				vec4 t::LAYER::;
				::foreach UNITS::
				::if !FIRST ::else ::end::::if !LAST ::if (::UNIT:: < ::UNIT_VALUE::)::end::
					t::LAYER:: = texture::if !isES3::2D::end::(::TEXTURE::, ::TEXCOORD::);
				::end::
				::end_ELEMENT_LAYER::
				::end::
			::end::
		::end::
		
		// calc final color from all layers
		vec4 col = ::FRAGMENT_CALC_LAYER::;
		
		::if isDISCARD:: 
			if (col.a <= ::DISCARD::) discard;
		::end::
		
		::if isPICKING:: 
			::if !isES3::gl_Frag::end::Color = vElement;
		::else::
			::if !isES3::gl_Frag::end::Color = col;
			// this fixing problem on old FF if alpha goes zero
			::if !isES3::gl_Frag::end::Color.w = clamp(::if !isES3::gl_Frag::end::Color.w, 0.003, 1.0);
		::end::
	}
	";

	
	
	
	
}