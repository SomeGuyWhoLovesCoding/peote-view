package peote.view.intern;

import peote.view.PeoteGL.GLBuffer;

class UniformBufferDisplay
{
	var uniformBytesPointer: GLBufferPointer;
	
	public static inline var block:Int = 1;
	public var uniformBuffer:GLBuffer;
	
	var uniformBytes:BufferBytes;
	

	public function new() 
	{
		//uniformBytes = Bytes.alloc(3 * 4);
		uniformBytes = BufferBytes.alloc(2 * 4*4);  // alignment to vec4 (2 values)
		uniformBytesPointer   = new GLBufferPointer(uniformBytes);
	}

	public inline function update(gl:PeoteGL) {
		gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
		gl.bufferData(gl.UNIFORM_BUFFER, uniformBytes.length, uniformBytesPointer, gl.STATIC_DRAW);
		gl.bindBuffer(gl.UNIFORM_BUFFER, null);
	}
	
	public inline function updateXOffset(xo:Float) {
		if (uniformBytes != null) uniformBytes.setFloat(0, xo);
	}

	public inline function updateYOffset(yo:Float) {
		if (uniformBytes != null) uniformBytes.setFloat(4, yo);
	}

	public inline function updateZoom(xz:Float, yz:Float) {
		if (uniformBytes != null) uniformBytes.setFloat(8,  xz);
		if (uniformBytes != null) uniformBytes.setFloat(12, yz);
	}
	
	public inline function updateXZoom(xz:Float) {
		if (uniformBytes != null) uniformBytes.setFloat(8, xz);
	}
	
	public inline function updateYZoom(yz:Float) {
		if (uniformBytes != null) uniformBytes.setFloat(12, yz);
	}

	public function createGLBuffer(gl:PeoteGL, xOffest:Float, yOffest:Float, xz:Float, yz:Float)
	{
		uniformBuffer = gl.createBuffer();
		if (uniformBytes != null) {
			uniformBytes.setFloat(0,  xOffest);
			uniformBytes.setFloat(4,  yOffest);
			uniformBytes.setFloat(8,  xz);
			uniformBytes.setFloat(12, yz);
		}
		uniformBytesPointer = new GLBufferPointer(uniformBytes);
		update(gl);
	}
	
	public function deleteGLBuffer(gl:PeoteGL)
	{
		gl.deleteBuffer(uniformBuffer);
	}
	
}