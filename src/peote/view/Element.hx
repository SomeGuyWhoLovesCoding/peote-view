package peote.view;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.ExprTools;
#end

@:remove @:autoBuild(peote.view.ElementImpl.build())
interface Element {}

class ElementImpl
{
#if macro
	static var rComments:EReg = new EReg("//.*?$","gm");
	static var rEmptylines:EReg = new EReg("([ \t]*\r?\n)+", "g");
	static var rStartspaces:EReg = new EReg("^([ \t]*\r?\n)+", "g");
	
	static inline function parseShader(shader:String):String {
		var template = new utils.MultipassTemplate(shader);
		var s = rStartspaces.replace(rEmptylines.replace(rComments.replace(template.execute(glConf), ""), "\n"), "");
		return s;
	}
	
	static function hasMeta(f:Field, s:String):Bool {for (m in f.meta) { if (m.name == s || m.name == ':$s') return true; } return false; }
	static function getMetaParam(f:Field, s:String):String {
		var p = null;
		var found = false;
		for (m in f.meta) if (m.name == s || m.name == ':$s') { p = m.params[0]; found = true; break; }
		if (found) {
			if (p != null) {
				switch (p.expr) {
					case EConst(CString(value)): return value;
					case EConst(CInt(value)): return value;
					default: return "";
				}
			} else return "";
		} else return null;
	}
	static var allowForBuffer = [{ name:":allow", params:[macro peote.view], pos:Context.currentPos()}];
	
	static var glConf = {
		isPICK:false,
		UNIFORM_TIME:"",
		ATTRIB_TIME:"", ATTRIB_SIZE:"", ATTRIB_POS:"",
		CALC_TIME:"", CALC_SIZE:"", CALC_POS:"",
	};
	
	static var conf = {
		time: [],

		size: { n:0, isAnim:false },
		sizeX: { name:"", isStart:false, isEnd:false, vStart:100, vEnd:100, set: "", time: "" },
		sizeY: { name:"", isStart:false, isEnd:false, vStart:100, vEnd:100, set: "", time: "" },
		
		pos: { n:0, isAnim:false },
		posX: { name: "", isStart:false, isEnd:false, vStart:0, vEnd:0, set: "", time: "" },
		posY: { name: "", isStart:false, isEnd:false, vStart:0, vEnd:0, set: "", time: "" },		
		
	};

	public static function checkMetas(f:Field, size:Dynamic, sizeX:Dynamic, time:Array<String>)
	{
		sizeX.name = f.name;
		var param:String = getMetaParam(f, "set");	if (param != null) sizeX.set = param;
		param = getMetaParam(f, "time");
		if (param != null) {
			size.isAnim = true;
			if (time.indexOf(param) == -1) time.push(param);
			sizeX.time = param;
			param = getMetaParam(f, "constStart");
			if (param != null) {
				if (param == "") throw Context.error('Error: @constStart needs a value', f.pos);
				sizeX.vStart = Std.parseInt(param);
			} else {
				sizeX.isStart = true;
				size.n++;
			}
			param = getMetaParam(f, "constEnd");
			if (param != null) {
				if (param == "") throw Context.error('Error: @constEnd needs a value', f.pos);
				sizeX.vEnd = Std.parseInt(param);
			} else {
				sizeX.isEnd = true;
				size.n++;
			}
		} else {
			param = getMetaParam(f, "const");
			if (param != null) {
				if (param == "") throw Context.error('Error: @const needs a value', f.pos);
				sizeX.vStart = Std.parseInt(param);
			} else {
				sizeX.isStart = true;
				size.n++;
			}							
		}
		trace(f.name,sizeX);
	}
	
	public static function build()
	{
		var hasNoNew:Bool = true;
		
		
		var classname = Context.getLocalClass().get().name;
		//var classpackage = Context.getLocalClass().get().pack;
		
		trace("--------------- " + classname + " -------------------");
		
		// trace(Context.getLocalClass().get().superClass); 
		trace("autogenerate shaders and buffers");

		// TODO: childclasses!

		var fields = Context.getBuildFields();
		for (f in fields)
		{
			var param:String;
			if (f.name == "new") {
				hasNoNew = false;
			}
			else
			switch (f.kind)
			{
				case FVar(t): //trace("attribute:",f.name ); // t: TPath({ name => Int, pack => [], params => [] })
					if      ( hasMeta(f, "posX") ) checkMetas(f, conf.pos, conf.posX, conf.time);
					else if ( hasMeta(f, "posY") ) checkMetas(f, conf.pos, conf.posY, conf.time);
					else if ( hasMeta(f, "sizeX") ) checkMetas(f, conf.size, conf.sizeX, conf.time);
					else if ( hasMeta(f, "sizeY") ) checkMetas(f, conf.size, conf.sizeY, conf.time);
					// TODO
					
				default: //throw Context.error('Error: attribute has to be an variable.', f.pos);
			}

		}
		// -----------------------------------------------------------------------------------

		for (i in 0...Std.int((conf.time.length + 1) / 2)) {
			if ((i == Std.int(conf.time.length / 2)) && (conf.time.length % 2 != 0))
			     glConf.ATTRIB_TIME += '::IN:: vec2 aTime$i;';
			else glConf.ATTRIB_TIME += '::IN:: vec4 aTime$i;';
		}
		
		if (conf.size.n > 0) glConf.ATTRIB_SIZE = '::IN:: ${ (conf.size.n==1) ? "float" : "vec"+conf.size.n} aSize;';
		if (conf.pos.n  > 0) glConf.ATTRIB_POS  = '::IN:: ${ (conf.pos.n ==1) ? "float" : "vec"+conf.pos.n } aPos;';
		
		// CALC TIME-MUTLIPLICATOR:
		for (i in 0...conf.time.length) {
			var t:String = "" + Std.int(i / 2);
			var d:String = "" + Std.int(i/2);
			if (i % 2 == 0) { t += ".x"; d += ".y"; } else { t += ".z"; d += ".w"; } 
			glConf.CALC_TIME += 'float time$i = clamp( (uTime - aTime$t) / aTime$d, 0.0, 1.0);';
		}
		if (conf.time.length > 0) glConf.UNIFORM_TIME = "uniform float uTime;";
		
		// PREPARE -----------------------------------------------------------                             <- SIZE, POS
		var prepare = function(name:String, size:Dynamic, sizeX:Dynamic, sizeY:Dynamic, time:Array<String>):String {
			var start = name; var end = name;
			if (sizeX.isStart && !sizeY.isStart) {
				if (size.n > 1) { start += ".x"; end += ".y"; }
				start = 'vec2( $start, ${sizeY.vStart}.0 )';
			}
			else if (!sizeX.isStart && sizeY.isStart) {
				if (size.n > 1) { start += ".x"; end += ".y"; }
				start = 'vec2( ${sizeX.vStart}.0, $start )';
			}
			else if (!sizeX.isStart && !sizeY.isStart)
				start= 'vec2( ${sizeX.vStart}.0, ${sizeY.vStart}.0 )';
			else if (size.n > 2) {
				start += ".xy"; end += ".z";
			}
			// ANIM
			if (size.isAnim) {
				if (sizeX.isEnd && !sizeY.isEnd)       end = 'vec2( $end, ${sizeY.vEnd}.0 )';
				else if (!sizeX.isEnd && sizeY.isEnd)  end = 'vec2( ${sizeX.vEnd}.0, $end )';
				else if (!sizeX.isEnd && !sizeY.isEnd) end = 'vec2( ${sizeX.vEnd}.0, ${sizeY.vEnd}.0 )';
				else {
					if      (end == "aSize.y") end += "z";
					else if (end == "aSize.z") end += "w";
				}
				var iX = time.indexOf(sizeX.time);
				var iY = time.indexOf(sizeY.time);
				if (iX == -1)      return '( $start + ($end - $start) * vec2( 0.0, time$iY ) )';
				else if (iY == -1) return '( $start + ($end - $start) * vec2( time$iX, 0.0 ) )';
				else               return '( $start + ($end - $start) * vec2( time$iX, time$iY ) )';
			} else return start;
		}
		
		glConf.CALC_SIZE = "vec2 size = aPosition * " + prepare("aSize", conf.size, conf.sizeX, conf.sizeY, conf.time) +";";
		glConf.CALC_POS  = "vec2 pos  = size + "      + prepare("aPos" , conf.pos,  conf.posX,  conf.posY,  conf.time) +";";
		

		
		// -----------------------------------------------------------------------------------
		
		var vertex_count = 6;
		
		var buff_size_instanced = conf.pos.n*2 + conf.size.n*2 + conf.time.length*8;
		var buff_size = vertex_count * (2+buff_size_instanced ); //+2
		// TODO: fix stride webgl1(IE)-Problem
		
		// ---------------------- vertex count and bufsize -----------------------------------
		fields.push({
			name:  "VERTEX_COUNT",
			meta:  allowForBuffer,
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:Int, macro $v{vertex_count}), 
			pos: Context.currentPos(),
		});
		fields.push({
			name:  "BUFF_SIZE",
			meta:  allowForBuffer,
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:Int, macro $v{buff_size}), 
			pos: Context.currentPos(),
		});
		fields.push({
			name:  "BUFF_SIZE_INSTANCED", // only for instanceDrawing
			meta:  allowForBuffer,
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:Int, macro $v{buff_size_instanced}), 
			pos: Context.currentPos(),
		});
		// ---------------------- vertex attribute bindings ----------------------------------
		var attrNumber = 0;
		fields.push({
			name:  "aPOSITION",
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:Int, macro $v{attrNumber++}), 
			pos: Context.currentPos(),
		});
		if (conf.pos.n > 0) 
			fields.push({
				name:  "aPOS",
				access:  [Access.APrivate, Access.AStatic, Access.AInline],
				kind: FieldType.FVar(macro:Int, macro $v{attrNumber++}), 
				pos: Context.currentPos(),
			});
		if (conf.size.n > 0)
			fields.push({
				name:  "aSIZE",
				access:  [Access.APrivate, Access.AStatic, Access.AInline],
				kind: FieldType.FVar(macro:Int, macro $v{attrNumber++}), 
				pos: Context.currentPos(),
			});
		for (i in 0...Std.int((conf.time.length+1) / 2)) {
			fields.push({
				name:  "aTIME"+i,
				access:  [Access.APrivate, Access.AStatic, Access.AInline],
				kind: FieldType.FVar(macro:Int, macro $v{attrNumber++}), 
				pos: Context.currentPos(),
			});
		}

		// TODO: COLOR...
		/*fields.push({
			name:  "aCOLOR",
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:Int, macro $v{3}), 
			pos: Context.currentPos(),
		});*/
			
		
		// ---------------------- bytePos and  dataPointer ----------------------------------
		fields.push({
			name:  "bytePos",
			meta:  allowForBuffer,
			access:  [Access.APrivate],
			kind: FieldType.FVar(macro:Int, macro $v{-1}), 
			pos: Context.currentPos(),
		});
		fields.push({
			name:  "dataPointer",
			meta:  allowForBuffer,
			access:  [Access.APrivate],
			kind: FieldType.FVar(macro:peote.view.PeoteGL.DataPointer, null), 
			pos: Context.currentPos(),
		});

		// -------------------------- instancedrawing --------------------------------------
		fields.push({
			name:  "instanceBytes", // only for instanceDrawing
			access:  [Access.APrivate, Access.AStatic],
			kind: FieldType.FVar(macro:haxe.io.Bytes, macro null), 
			pos: Context.currentPos(),
		});
		fields.push({
			name: "createInstanceBytes", // only for instanceDrawing
			meta:  allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args: [],
				expr: macro {
					if (instanceBytes == null) {
						trace("create bytes for instance GLbuffer");
						instanceBytes = haxe.io.Bytes.alloc(VERTEX_COUNT * 2);
						instanceBytes.set(0 , 1); instanceBytes.set(1,  1);
						instanceBytes.set(2 , 1); instanceBytes.set(3,  1);
						instanceBytes.set(4 , 0); instanceBytes.set(5,  1);
						instanceBytes.set(6 , 1); instanceBytes.set(7,  0);
						instanceBytes.set(8 , 0); instanceBytes.set(9,  0);
						instanceBytes.set(10, 0); instanceBytes.set(11, 0);
					}
				},
				ret: null
			})
		});
		fields.push({
			name: "updateInstanceGLBuffer",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL},
				       {name:"glInstanceBuffer", type:macro:peote.view.PeoteGL.GLBuffer}
				],
				expr: macro {
					trace("fill full instance GLbuffer");
					gl.bindBuffer (gl.ARRAY_BUFFER, glInstanceBuffer);
					gl.bufferData (gl.ARRAY_BUFFER, instanceBytes.length, instanceBytes, gl.STATIC_DRAW);
					gl.bindBuffer (gl.ARRAY_BUFFER, null);
				},
				ret: null
			})
		});
		
		// ----------------------------- writeBytes -----------------------------------------
		function writeBytesExpr(verts:Array<Array<Int>>=null):Array<Expr> {
			var i:Int = 0;
			var exprBlock = new Array<Expr>();
			var len = 1;
			if (verts != null) len = verts.length;			
			for (j in 0...len)
			{
				if (verts != null) {
					exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $v{verts[j][0]}) ); i++;
					exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $v{verts[j][1]}) ); i++;
				}
				
				if (conf.pos.isAnim) {
					if (conf.posX.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posX.name+"Start"}) ); i+=2; }
					if (conf.posY.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posY.name+"Start"}) ); i+=2; }
					if (conf.posX.isEnd)   { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posX.name+"End"}) ); i+=2; }
					if (conf.posY.isEnd)   { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posY.name+"End"}) ); i+=2; }
				} else {
					if (conf.posX.isStart ) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posX.name }) ); i+=2; }
					if (conf.posY.isStart ) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.posY.name }) ); i+=2; }
				}
				
				if (conf.size.isAnim) {
					if (conf.sizeX.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeX.name+"Start"}) ); i+=2; }
					if (conf.sizeY.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeY.name+"Start"}) ); i+=2; }
					if (conf.sizeX.isEnd)   { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeX.name+"End"}) ); i+=2; }
					if (conf.sizeY.isEnd)   { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeY.name+"End"}) ); i+=2; }
				} else {
					if (conf.sizeX.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeX.name}) ); i+=2; }
					if (conf.sizeY.isStart) { exprBlock.push( macro bytes.setUInt16(bytePos + $v{i}, $i{conf.sizeY.name}) ); i+=2; }
				}
				// TODO: fix stride webgl1(IE)-Problem
				for (t in conf.time) {
					exprBlock.push( macro bytes.setFloat(bytePos + $v{i}, $i{"time"+t+"Start"}) ); i+=4;
					exprBlock.push( macro bytes.setFloat(bytePos + $v{i}, $i{"time"+t+"Duration"}) ); i+=4;
				}
			}
			return exprBlock;
		}

		fields.push({
			name: "writeBytesInstanced",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"bytes", type:macro:haxe.io.Bytes}
				],
				expr: macro $b{ writeBytesExpr() },
				ret: null
			})
		});
		// -------------------------	
		fields.push({
			name: "writeBytes",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"bytes", type:macro:haxe.io.Bytes}
				],
				expr: macro $b{ writeBytesExpr([[1,1],[1,1],[0,1],[1,0],[0,0],[0,0]]) },
				ret: null
			})
		});
				
		// ----------------------------- updateGLBuffer -------------------------------------
		fields.push({
			name: "updateGLBuffer",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL},
				       {name:"glBuffer", type:macro:peote.view.PeoteGL.GLBuffer},
				       {name:"elemBuffSize", type:macro:Int}
				],
				expr: macro {
					gl.bindBuffer (gl.ARRAY_BUFFER, glBuffer);
					gl.bufferSubData(gl.ARRAY_BUFFER, bytePos, elemBuffSize, dataPointer );
					gl.bindBuffer (gl.ARRAY_BUFFER, null);
				},
				ret: null
			})
		});
		
		// ------------------ bind vertex attributes to program ----------------------------------
		var exprBlock = [ macro gl.bindAttribLocation(glProgram, aPOSITION, "aPosition") ];
		if (conf.pos.n  > 0 ) exprBlock.push( macro gl.bindAttribLocation(glProgram, aPOS,  "aPos" ) );
		if (conf.size.n > 0 ) exprBlock.push( macro gl.bindAttribLocation(glProgram, aSIZE, "aSize") );
		for (j in 0...Std.int((conf.time.length+1) / 2) )
			exprBlock.push( macro gl.bindAttribLocation(glProgram, $i{"aTIME" + j}, $v{"aTime"+j} ) );
				
		fields.push({
			name: "bindAttribLocations",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL},
				       {name:"glProgram", type:macro:peote.view.PeoteGL.GLProgram}
				],
				expr: macro $b{exprBlock},
				ret: null
			})
		});
				
		// ------------------------ enable/disable vertex attributes ------------------------------
		function enableVertexAttribExpr(isInstanced:Bool=false):Array<Expr> {
			var i:Int = 0;
			var exprBlock = new Array<Expr>();
			var stride = buff_size_instanced;
			if (isInstanced) {
				exprBlock.push( macro gl.bindBuffer(gl.ARRAY_BUFFER, glInstanceBuffer) );
				exprBlock.push( macro gl.enableVertexAttribArray (aPOSITION) );
				exprBlock.push( macro gl.vertexAttribPointer(aPOSITION, 2, gl.UNSIGNED_BYTE, false, 2, 0 ) );
				exprBlock.push( macro gl.bindBuffer(gl.ARRAY_BUFFER, glBuffer) );
			} else {
				stride += 2; //+2;
				exprBlock.push( macro gl.bindBuffer(gl.ARRAY_BUFFER, glBuffer) );
				exprBlock.push( macro gl.enableVertexAttribArray (aPOSITION) );
				exprBlock.push( macro gl.vertexAttribPointer(aPOSITION, 2, gl.UNSIGNED_BYTE, false, $v{stride}, 0 )); i+=2;
			}
			
			if (conf.pos.n  > 0 ) {
				exprBlock.push( macro gl.enableVertexAttribArray (aPOS) );
				exprBlock.push( macro gl.vertexAttribPointer(aPOS, $v{conf.pos.n}, gl.SHORT, false, $v{stride}, $v{i} ) ); i += conf.pos.n * 2;
				if (isInstanced) exprBlock.push( macro gl.vertexAttribDivisor(aPOS, 1) );			
			}
			if (conf.size.n > 0 ) {
				exprBlock.push( macro gl.enableVertexAttribArray (aSIZE) );
				exprBlock.push( macro gl.vertexAttribPointer(aSIZE, $v{conf.size.n}, gl.SHORT, false, $v{stride}, $v{i} ) ); i += conf.size.n * 2;
				if (isInstanced) exprBlock.push( macro gl.vertexAttribDivisor(aSIZE, 1) );			
			}
			// TODO: fix stride webgl1(IE)-Problem
			for (j in 0...Std.int((conf.time.length+1) / 2) ) {
				exprBlock.push( macro gl.enableVertexAttribArray ($i{"aTIME" + j}) );
				var n = ((j==Std.int(conf.time.length / 2)) && (conf.time.length % 2 != 0)) ? 2 : 4;
				exprBlock.push( macro gl.vertexAttribPointer($i{"aTIME"+j}, $v{n}, gl.FLOAT, false, $v{stride}, $v{i} ) ); i += n * 4;
				if (isInstanced) exprBlock.push( macro gl.vertexAttribDivisor($i{"aTIME"+j}, 1) );			
			}
			//for (e in exprBlock) trace(ExprTools.toString( e));
			return exprBlock;
		}
		fields.push({
			name: "enableVertexAttribInstanced",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL},
				       {name:"glBuffer", type:macro:peote.view.PeoteGL.GLBuffer},
				       {name:"glInstanceBuffer", type:macro:peote.view.PeoteGL.GLBuffer}
				],
				expr: macro $b{ enableVertexAttribExpr(true) },
				ret: null
			})
		});
		// -------------------------
		fields.push({
			name: "enableVertexAttrib",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL},
				       {name:"glBuffer", type:macro:peote.view.PeoteGL.GLBuffer}
				],
				expr: macro $b{ enableVertexAttribExpr() },
				ret: null
			})
		});
		// -------------------------
		exprBlock = [ macro gl.disableVertexAttribArray (aPOSITION) ];
		if (conf.pos.n  >0 ) exprBlock.push( macro gl.disableVertexAttribArray (aPOS ) );
		if (conf.size.n >0 ) exprBlock.push( macro gl.disableVertexAttribArray (aSIZE) );
		for (i in 0...Std.int((conf.time.length+1) / 2)) exprBlock.push( macro gl.disableVertexAttribArray ($i{"aTIME"+i}) );
		
		fields.push({
			name: "disableVertexAttrib",
			meta: allowForBuffer,
			access: [Access.APrivate, Access.AStatic, Access.AInline],
			pos: Context.currentPos(),
			kind: FFun({
				args:[ {name:"gl", type:macro:peote.view.PeoteGL}
				],
				expr: macro $b{exprBlock},
				ret: null
			})
		});

				
		// ----------------------- shader generation ------------------------
		fields.push({
			name:  "vertexShader",
			meta:  allowForBuffer,
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:String, macro $v{parseShader(Shader.vertexShader)}), 
			pos: Context.currentPos(),
		});
		//trace("ELEMENT ---------- \n"+parseShader(Shader.vertexShader));
		fields.push({
			name:  "fragmentShader",
			meta:  allowForBuffer,
			access:  [Access.APrivate, Access.AStatic, Access.AInline],
			kind: FieldType.FVar(macro:String, macro $v{parseShader(Shader.fragmentShader)}),
			pos: Context.currentPos(),
		});
		
		
		return fields; // <------ classgeneration complete !
	}
	
	

#end
}