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

    // Seeds uniformBytes from the live uniform values.
    // Called at construction and again in createGLBuffer() to capture
    // any value changes that happened before the GL context existed.
    inline function seedBytes() {
        for (i in 0...floats.length)
            uniformBytes.setFloat(floatOffsets[i], floats[i].value);
        for (i in 0...vectors.length) {
            var v = vectors[i].value;
            var offset = vectorOffsets[i];
            var count = (v != null) ? v.length : 0;
            for (c in 0...count)
                uniformBytes.setFloat(offset + c * 4, v[c]);
        }
    }

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

        seedBytes();
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
            var count = (values != null) ? values.length : 0;
            for (c in 0...count)
                uniformBytes.setFloat(offset + c * 4, values[c]);
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

    // ES 3.1 introspection constants — defined locally because Lime's native
    // binding does not always expose these as accessible Haxe properties.
    static inline var GL_UNIFORM_BLOCK_DATA_SIZE              = 0x8A40;
    static inline var GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS        = 0x8A42;
    static inline var GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = 0x8A43;
    static inline var GL_UNIFORM_OFFSET                       = 0x8A3B;

    // Queries the GPU-linked program for the exact std140 byte offsets of every
    // member in the "uboCustom" block and replaces the constructor-computed
    // floatOffsets/vectorOffsets with the authoritative values.
    // Must be called after GLTool.linkGLProgram and only when Version.isES31.
    public function applyIntrospectedOffsets(gl:PeoteGL, glProg:peote.view.PeoteGL.GLProgram):Void
    {
        var blockIndex = gl.getUniformBlockIndex(glProg, "uboCustom");
        if (blockIndex == gl.INVALID_INDEX) return;

        // Authoritative total size from the linker
        var result = new lime.utils.UInt8Array(4);
        gl.getActiveUniformBlockiv(glProg, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, result);
        var blockSize:Int = result[0] | (result[1] << 8) | (result[2] << 16) | (result[3] << 24);

        //trace(untyped result.view.bytes.toString());
        //var blockSize:Int = result[0];
        if (blockSize <= 0) {
            #if peoteview_debug_program
            trace("applyIntrospectedOffsets: UNIFORM_BLOCK_DATA_SIZE returned " + blockSize + ", keeping constructor layout");
            #end
            return;
        }

        // Collect indices of all uniforms that belong to this block
        gl.getActiveUniformBlockiv(glProg, blockIndex, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS, result);
        var numBlockUniforms:Int = result[0];
        if (numBlockUniforms <= 0) {
            #if peoteview_debug_program
            trace("applyIntrospectedOffsets: UNIFORM_BLOCK_ACTIVE_UNIFORMS returned " + numBlockUniforms + ", keeping constructor layout");
            #end
            return;
        }

        #if peoteview_debug_program
        trace("applyIntrospectedOffsets: blockSize=" + blockSize + " numUniforms=" + numBlockUniforms);
        #end

        var blockUniformIndices = new lime.utils.UInt8Array(numBlockUniforms * 4);
        gl.getActiveUniformBlockiv(glProg, blockIndex, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, blockUniformIndices);

        // For each member, query its name and byte offset
        var memberOffsets = new haxe.ds.StringMap<Int>();
        var offsets = new lime.utils.UInt8Array(4);
        for (i in 0...numBlockUniforms) {
            var idx:Int = blockUniformIndices[i*4    ]
                        | blockUniformIndices[i*4 + 1] << 8
                        | blockUniformIndices[i*4 + 2] << 16
                        | blockUniformIndices[i*4 + 3] << 24;
            var info = gl.getActiveUniform(glProg, idx);
            if (info == null) continue;
            gl.getActiveUniformsiv(glProg, [idx], GL_UNIFORM_OFFSET, offsets);
            var offset:Int = offsets[0] | (offsets[1] << 8) | (offsets[2] << 16) | (offsets[3] << 24);
            #if peoteview_debug_program
            trace("applyIntrospectedOffsets: member=" + info.name + " offset=" + offset);
            #end
            memberOffsets.set(info.name, offset);
        }

        // Remap floatOffsets by name
        for (i in 0...floats.length) {
            var queried = memberOffsets.get(floats[i].name);
            if (queried != null) floatOffsets[i] = queried;
        }

        // Remap vectorOffsets by name
        for (i in 0...vectors.length) {
            var queried = memberOffsets.get(vectors[i].name);
            if (queried != null) vectorOffsets[i] = queried;
        }

        // Reallocate uniformBytes to the GPU-reported block size and re-seed
        uniformBytes = BufferBytes.alloc(blockSize);
        bufferPointer = new GLBufferPointer(uniformBytes, 0);
        seedBytes();
    }

    public function createGLBuffer(gl:PeoteGL)
    {
        // Re-seed from live uniform values to capture any set_value calls
        // that happened before the GL context existed.
        seedBytes();

        uniformBuffer = gl.createBuffer();
        update(gl);
        isDirty = false;
    }

    public function deleteGLBuffer(gl:PeoteGL)
    {
        gl.deleteBuffer(uniformBuffer);
    }
}
