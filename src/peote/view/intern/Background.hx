package peote.view.intern;
import peote.view.PeoteGL.GLBuffer;
import peote.view.PeoteGL.GLProgram;
import peote.view.PeoteGL.GLShader;
import peote.view.PeoteGL.GLUniformLocation;
import peote.view.PeoteGL.GLVertexArrayObject;
import peote.view.PeoteGL.Precision;
// for rendering a colored background-GL-quad
class Background 
{
	var gl:PeoteGL;
	var buffer:GLBuffer;
	var glProgram:GLProgram;
	var glVAO:GLVertexArrayObject;
	
	static inline var aPOSITION:Int = 0;
	var uRGBA:GLUniformLocation;
	// Cached color values — uniform is only re-uploaded when these change
	var _ogR:Float = -1.0;
	var _ogG:Float = -1.0;
	var _ogB:Float = -1.0;
	var _ogA:Float = -1.0;
	public function new(gl:PeoteGL) {
		this.gl = gl;
		createBuffer();
		createProgram();
	}
	
	public function createBuffer():Void
	{
		var bytes = BufferBytes.alloc(8 * 4);
		bytes.setFloat(0,  1);bytes.setFloat(4,  1);
		bytes.setFloat(8,  0);bytes.setFloat(12, 1);
		bytes.setFloat(16, 1);bytes.setFloat(20, 0);
		bytes.setFloat(24, 0);bytes.setFloat(28, 0);
		
		buffer = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
		gl.bufferData(gl.ARRAY_BUFFER, 8*4, new GLBufferPointer(bytes), gl.STATIC_DRAW);
		gl.bindBuffer(gl.ARRAY_BUFFER, null);
	}
	
	public function createProgram():Void
	{
		var precision:String = "";
		
		if (Precision.availVertexFloat("lowp") != null) precision = "precision lowp float;";
		else if (Precision.availVertexFloat("mediump") != null) precision = "precision mediump float;";
		else if (Precision.availVertexFloat("highp") != null) precision = "precision highp float;";
		
		var glVertexShader:GLShader = GLTool.compileGLShader(gl, gl.VERTEX_SHADER,
		precision + "	
			attribute vec2 aPosition;
			void main(void)
			{
				gl_Position = mat4 (
					vec4(2.0, 0.0, 0.0, 0.0),
					vec4(0.0, -2.0, 0.0, 0.0),
					vec4(0.0, 0.0, -1.0, 0.0),
					vec4(-1.0, 1.0, 0.0, 1.0)
				) * vec4 (aPosition, -1.0 ,1.0);
			}
		"
		);
		
		if (Precision.availFragmentFloat("lowp") != null) precision = "precision lowp float;";
		else if (Precision.availFragmentFloat("mediump") != null) precision = "precision mediump float;";
		else if (Precision.availFragmentFloat("highp") != null) precision = "precision highp float;";
		
		var glFragmentShader:GLShader = GLTool.compileGLShader(gl, gl.FRAGMENT_SHADER,
		precision + "
			uniform vec4 uRGBA;
			void main(void)
			{
				gl_FragColor = uRGBA;
				
				// TODO: Fix for old FF
				gl_FragColor.w = clamp(uRGBA.w, 0.003, 1.0);
			}
		"			
		);
		glProgram = gl.createProgram();
		gl.attachShader(glProgram, glVertexShader);
		gl.attachShader(glProgram, glFragmentShader);
		
		gl.deleteShader(glVertexShader);
		gl.deleteShader(glFragmentShader);
		
		gl.bindAttribLocation(glProgram, aPOSITION, "aPosition");
		GLTool.linkGLProgram(gl, glProgram);
		uRGBA = gl.getUniformLocation(glProgram, "uRGBA");

		if (PeoteGL.Version.isVAO) {
			glVAO = gl.createVertexArray();
			gl.bindVertexArray(glVAO);
		}
		gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
		gl.enableVertexAttribArray(aPOSITION);
		gl.vertexAttribPointer(aPOSITION, 2, gl.FLOAT, false, 8, 0);
		gl.bindBuffer(gl.ARRAY_BUFFER, null);
		if (PeoteGL.Version.isVAO) gl.bindVertexArray(null);
	}
	
	public function render(r:Float, g:Float, b:Float, a:Float):Void
	{
		gl.useProgram(glProgram);
		// Only re-upload the uniform when the color has actually changed
		if (r != _ogR || g != _ogG || b != _ogB || a != _ogA) {
			gl.uniform4f(uRGBA, r, g, b, a);
			_ogR = r;
			_ogG = g;
			_ogB = b;
			_ogA = a;
		}
		if (PeoteGL.Version.isVAO) {
			gl.bindVertexArray(glVAO);
		} else {
			gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
			gl.enableVertexAttribArray(aPOSITION);
			gl.vertexAttribPointer(aPOSITION, 2, gl.FLOAT, false, 8, 0);
		}
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		if (PeoteGL.Version.isVAO) {
			gl.bindVertexArray(null);
		} else {
			gl.disableVertexAttribArray(aPOSITION);
			gl.bindBuffer(gl.ARRAY_BUFFER, null);
		}
	}
	
	
}
