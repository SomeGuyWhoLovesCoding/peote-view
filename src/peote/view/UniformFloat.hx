package peote.view;

import peote.view.PeoteGL.GLUniformLocation;

/**
	Set up a custom "uniform" that can be accessed within glsl shadercode.
**/
class UniformFloat
{
	/**The value that can be changed at runtime**/
	public var value(get, set):Float;
	private var _value:Float;

	inline function get_value():Float return _value;

	inline function set_value(v:Float):Float {
		if (program != null)
			program.updateUniformFloat(this, v);
		else
			_value = v;
		return v;
	}

	/**The identifier to be used within shadercode**/
	public var name(default, null):String;

	/**The program to be used in uniform buffer**/
	public var program:Program;
	
	/**
		Creates a new `UniformFloat` instance.
		@param name identifier to be used within shadercode
		@param value start value
		@param program optional program value
	**/
	public inline function new(name:String, value:Float) 
	{
		this.name = name;
		this._value = value;
	}
}