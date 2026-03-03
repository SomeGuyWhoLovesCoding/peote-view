package peote.view;

import peote.view.PeoteGL.GLUniformLocation;

/**
	Set up a custom "uniform" that can be accessed within glsl shadercode.
**/
class UniformVector
{
	/**The value that can be changed at runtime**/
	public var value:Array<Float>;

	/**The identifier to be used within shadercode**/
	public var name(default, null):String;
	
	/**
		Creates a new `UniformVector` instance.
		@param name identifier to be used within shadercode
		@param value start value (one = `float`, two = `vec2(x,y)`, three = `vec3(x,y,z)`, four = `vec4(w,x,y,z)`, five and above = falls directly onto `vec4(w,x,y,z)`).
	**/
	public inline function new(name:String, value:Array<Float>) 
	{
		this.name = name;
		this.value = value;
	}
	
}
