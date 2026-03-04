package peote.view.intern;

import peote.view.PeoteGL.GLBuffer;
import peote.view.UniformFloat;
import peote.view.UniformVector;

class UniformBufferCustom 
{
    public static inline var block:Int = 2;
    public var uniformBuffer:GLBuffer;
    public var isDirty:Bool = false;

    var uniformBytes:BufferBytes;
    var bufferPointer:GLBufferPointer; // points at offset 0 of uniformBytes

    var floatOffsets:Array<Int>;
    var vectorOffsets:Array<Int>;
    var vectorTypes:Array<String>;

    var floats:Array<UniformFloat>;
    var vectors:Array<UniformVector>;

    public function new(floats:Array<UniformFloat>, vectors:Array<UniformVector>) 
    {
        this.floats = floats;
        this.vectors = vectors;

        var totalSize = 0;
        floatOffsets  = [];
        vectorOffsets = [];
        vectorTypes   = [];

        // Floats — packed, 4 bytes each
        for (f in floats) {
            floatOffsets.push(totalSize);
            totalSize += 4;
        }

        // Align to vec4 boundary before vectors
        var vectorStart = Math.ceil(totalSize / 16) * 16;

        // Vectors — 16 bytes each regardless of component count (std140)
        for (i in 0...vectors.length) {
            vectorOffsets.push(vectorStart + i * 16);
            var type = "vec4";
            if (vectors[i].value != null) {
                switch (vectors[i].value.length) {
                    case 2: type = "vec2";
                    case 3: type = "vec3";
                    case 4: type = "vec4";
                }
            }
            vectorTypes.push(type);
        }

        var totalBufferSize = vectorStart + vectors.length * 16;
        uniformBytes = BufferBytes.alloc(totalBufferSize);
        bufferPointer = new GLBufferPointer(uniformBytes, 0);

        // Seed bytes from initial values
        for (i in 0...floats.length)
            uniformBytes.setFloat(floatOffsets[i], floats[i].value);
        for (i in 0...vectors.length) {
            var v = vectors[i].value;
            var offset = vectorOffsets[i];
            uniformBytes.setFloat(offset,      (v != null && v.length >= 1) ? v[0] : 0.0);
            uniformBytes.setFloat(offset + 4,  (v != null && v.length >= 2) ? v[1] : 0.0);
            uniformBytes.setFloat(offset + 8,  (v != null && v.length >= 3) ? v[2] : 0.0);
            uniformBytes.setFloat(offset + 12, (v != null && v.length >= 4) ? v[3] : 0.0);
        }
    }

    public inline function update(gl:PeoteGL) {
        gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
        gl.bufferData(gl.UNIFORM_BUFFER, uniformBytes.length, bufferPointer, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, null);
    }

    public inline function updateFloat(gl:PeoteGL, index:Int, value:Float) {
        if (gl != null) {
            uniformBytes.setFloat(floatOffsets[index], value);
            isDirty = true;
        }
    }

    public inline function updateVector(gl:PeoteGL, index:Int, values:Array<Float>) {
        if (gl != null) {
            var offset = vectorOffsets[index];
            uniformBytes.setFloat(offset,      (values != null && values.length >= 1) ? values[0] : 0.0);
            uniformBytes.setFloat(offset + 4,  (values != null && values.length >= 2) ? values[1] : 0.0);
            uniformBytes.setFloat(offset + 8,  (values != null && values.length >= 3) ? values[2] : 0.0);
            uniformBytes.setFloat(offset + 12, (values != null && values.length >= 4) ? values[3] : 0.0);
            isDirty = true;
        }
    }

    public inline function flushIfDirty(gl:PeoteGL) {
        if (!isDirty) return;
        gl.bindBuffer(gl.UNIFORM_BUFFER, uniformBuffer);
        gl.bufferSubData(gl.UNIFORM_BUFFER, 0, uniformBytes.length, bufferPointer);
        gl.bindBuffer(gl.UNIFORM_BUFFER, null);
        isDirty = false;
    }

    public inline function getFloat(index:Int):Float {
        return uniformBytes.getFloat(floatOffsets[index]);
    }

    public inline function getVector(index:Int):Array<Float> {
        var offset = vectorOffsets[index];
        return [
            uniformBytes.getFloat(offset),
            uniformBytes.getFloat(offset + 4),
            uniformBytes.getFloat(offset + 8),
            uniformBytes.getFloat(offset + 12)
        ];
    }

    public function createGLBuffer(gl:PeoteGL)
    {
        // Re-seed from live uniform values to capture any set_value calls
        // that happened before the GL context existed.
        for (i in 0...floats.length)
            uniformBytes.setFloat(floatOffsets[i], floats[i].value);
        for (i in 0...vectors.length) {
            var v = vectors[i].value;
            var offset = vectorOffsets[i];
            uniformBytes.setFloat(offset,      (v != null && v.length >= 1) ? v[0] : 0.0);
            uniformBytes.setFloat(offset + 4,  (v != null && v.length >= 2) ? v[1] : 0.0);
            uniformBytes.setFloat(offset + 8,  (v != null && v.length >= 3) ? v[2] : 0.0);
            uniformBytes.setFloat(offset + 12, (v != null && v.length >= 4) ? v[3] : 0.0);
        }

        uniformBuffer = gl.createBuffer();
        update(gl);
        isDirty = false;
    }

    public function deleteGLBuffer(gl:PeoteGL)
    {
        gl.deleteBuffer(uniformBuffer);
    }
}
