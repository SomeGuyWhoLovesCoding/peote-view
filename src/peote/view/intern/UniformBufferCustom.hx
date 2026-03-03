package peote.view.intern;

import peote.view.PeoteGL.GLBuffer;
import peote.view.UniformFloat;
import peote.view.UniformVector;

class UniformBufferCustom 
{
    public static inline var block:Int = 2;
    public var uniformBuffer:GLBuffer;
    
    var uniformBytes:BufferBytes;
    var floatOffsets:Array<Int>;
    var vectorOffsets:Array<Int>;
    var vectorTypes:Array<String>; // Store the original type
    
    var floats:Array<UniformFloat>;
    var vectors:Array<UniformVector>;
    
    public function new(floats:Array<UniformFloat>, vectors:Array<UniformVector>) 
    {
        this.floats = floats;
        this.vectors = vectors;
        
        // Calculate buffer size (aligned to vec4 boundaries)
        var totalSize = 0;
        floatOffsets = [];
        vectorOffsets = [];
        vectorTypes = [];
        
        // Floats can be packed (each float = 4 bytes)
        for (f in floats) {
            floatOffsets.push(totalSize);
            totalSize += 4;
        }
        
        // Align to vec4 boundary for vectors
        var vectorStart = Math.ceil(totalSize / 16) * 16;
        
        // Calculate offsets for vectors (each gets 16 bytes regardless of type)
        for (i in 0...vectors.length) {
            vectorOffsets.push(vectorStart + i * 16);
            
            // Store the original type
            var type = "vec4";
            if (vectors[i].value != null) {
                switch(vectors[i].value.length) {
                    case 2: type = "vec2";
                    case 3: type = "vec3";
                    case 4: type = "vec4";
                }
            }
            vectorTypes.push(type);
        }
        
        var totalBufferSize = vectorStart + vectors.length * 16;
        uniformBytes = BufferBytes.alloc(totalBufferSize);
        
        // Initialize with current values
        for (i in 0...floats.length) {
            uniformBytes.setFloat(floatOffsets[i], floats[i].value);
        }
        
        for (i in 0...vectors.length) {
            var v = vectors[i].value;
            var offset = vectorOffsets[i];
            
            // Always write all 4 components (default to 0.0 for missing ones)
            uniformBytes.setFloat(offset,      (v != null && v.length >= 1) ? v[0] : 0.0);
            uniformBytes.setFloat(offset + 4,  (v != null && v.length >= 2) ? v[1] : 0.0);
            uniformBytes.setFloat(offset + 8,  (v != null && v.length >= 3) ? v[2] : 0.0);
            uniformBytes.setFloat(offset + 12, (v != null && v.length >= 4) ? v[3] : 0.0);
        }
    }
    
    public inline function updateFloat(gl:PeoteGL, index:Int, value:Float) {
        if (gl != null) {
            uniformBytes.setFloat(floatOffsets[index], value);
            gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
            gl.bufferSubData(gl.UNIFORM_BUFFER, floatOffsets[index], 4, 
                new GLBufferPointer(uniformBytes, floatOffsets[index]));
            gl.bindBuffer(gl.UNIFORM_BUFFER, null);
        }
    }
    
    public inline function updateVector(gl:PeoteGL, index:Int, values:Array<Float>) {
        if (gl != null) {
            var offset = vectorOffsets[index];
            
            // Always update all 4 components (unused components are ignored in shader)
            uniformBytes.setFloat(offset,      (values != null && values.length >= 1) ? values[0] : 0.0);
            uniformBytes.setFloat(offset + 4,  (values != null && values.length >= 2) ? values[1] : 0.0);
            uniformBytes.setFloat(offset + 8,  (values != null && values.length >= 3) ? values[2] : 0.0);
            uniformBytes.setFloat(offset + 12, (values != null && values.length >= 4) ? values[3] : 0.0);
            
            gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
            gl.bufferSubData(gl.UNIFORM_BUFFER, offset, 16, 
                new GLBufferPointer(uniformBytes, offset));
            gl.bindBuffer(gl.UNIFORM_BUFFER, null);
        }
    }
    
    public function createGLBuffer(gl:PeoteGL)
    {
        uniformBuffer = gl.createBuffer();
        gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
        gl.bufferData(gl.UNIFORM_BUFFER, uniformBytes.length, 
            new GLBufferPointer(uniformBytes), gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, null);
    }
    
    public function deleteGLBuffer(gl:PeoteGL)
    {
        gl.deleteBuffer(uniformBuffer);
    }
}