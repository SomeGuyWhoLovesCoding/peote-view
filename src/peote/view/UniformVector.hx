package peote.view;

import peote.view.PeoteGL.GLUniformLocation;

/**
	Set up a custom "uniform" that can be accessed within glsl shadercode.
**/
class UniformVector
{
	/**The value that can be changed at runtime**/
	public var value(get, set):Array<Float>;
	private var _value:Array<Float>;

	inline function get_value():Array<Float> return _value;

	inline function set_value(v:Array<Float>):Array<Float> {
		if (program != null)
			program.updateUniformVector(this, v);
		else
			_value = v;
		return v;
	}

	/**The identifier to be used within shadercode**/
	public var name(default, null):String;

	/**The program to be used in uniform buffer**/
	public var program:Program;
	
	/**
		Creates a new `UniformVector` instance.
		@param name identifier to be used within shadercode
		@param value start value (uniform buffers auto-align to vec4s - one = `float`, two = `vec2(x,y)`, three = `vec3(x,y,z)`, four = `vec4(w,x,y,z)`, five and above = falls directly onto `vec4(w,x,y,z)`).
		@param program optional program value
	**/
	public inline function new(name:String, value:Array<Float>) 
	{
		this.name = name;
		this._value = value;
	}
}