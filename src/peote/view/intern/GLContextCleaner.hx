package peote.view.intern;

import peote.view.PeoteGL;
import peote.view.PeoteGL.GLProgram;
import peote.view.PeoteGL.GLShader;
import peote.view.PeoteGL.GLBuffer;
import peote.view.PeoteGL.GLVertexArrayObject;
import peote.view.PeoteGL.GLTexture;
import peote.view.PeoteGL.GLFramebuffer;
import peote.view.PeoteGL.GLRenderbuffer;

typedef PendingDeletion = {
    var programs:Array<GLProgram>;
    var shaders:Array<GLShader>;
    var buffers:Array<GLBuffer>;
    var vaos:Array<GLVertexArrayObject>;
    var textures:Array<GLTexture>;
    var framebuffers:Array<GLFramebuffer>;
    var renderbuffers:Array<GLRenderbuffer>;
}

class GLContextCleaner {
    static var pending:Map<PeoteGL, PendingDeletion> = new Map();

    public static function queue(gl:PeoteGL, deletion:PendingDeletion):Void {
        if (!pending.exists(gl)) {
            pending.set(gl, {
                programs: [],
                shaders: [],
                buffers: [],
                vaos: [],
                textures: [],
                framebuffers: [],
                renderbuffers: []
            });
        }
        var p = pending.get(gl);
        for (v in deletion.programs)     if (v != null) p.programs.push(v);
        for (v in deletion.shaders)      if (v != null) p.shaders.push(v);
        for (v in deletion.buffers)      if (v != null) p.buffers.push(v);
        for (v in deletion.vaos)         if (v != null) p.vaos.push(v);
        for (v in deletion.textures)     if (v != null) p.textures.push(v);
        for (v in deletion.framebuffers) if (v != null) p.framebuffers.push(v);
        for (v in deletion.renderbuffers)if (v != null) p.renderbuffers.push(v);
    }

    public static function flush(gl:PeoteGL):Void {
        var p = pending.get(gl);
        if (p == null) return;
        for (v in p.programs)      gl.deleteProgram(v);
        for (v in p.shaders)       gl.deleteShader(v);
        for (v in p.buffers)       gl.deleteBuffer(v);
        for (v in p.vaos)          gl.deleteVertexArray(v);
        for (v in p.textures)      gl.deleteTexture(v);
        for (v in p.framebuffers)  gl.deleteFramebuffer(v);
        for (v in p.renderbuffers) gl.deleteRenderbuffer(v);
        pending.remove(gl);
    }
}