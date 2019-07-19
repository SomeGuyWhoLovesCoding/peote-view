package peote.text;

#if !macro
@:genericBuild(peote.text.FontProgram.FontProgramMacro.build())
class FontProgram<T> {}
#else

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.TypeTools;

class FontProgramMacro
{
	public static var cache = new Map<String, Bool>();
	
	static public function build()
	{	
		switch (Context.getLocalType()) {
			case TInst(_, [t]):
				switch (t) {
					case TInst(n, []):
						var g = n.get();
						var superName:String = null;
						var superModule:String = null;
						var s = g;
						while (s.superClass != null) {
							s = s.superClass.t.get(); //trace("->" + s.name);
							superName = s.name;
							superModule = s.module;
						}			
						return buildClass("FontProgram",  g.pack, g.module, g.name, superModule, superName, TypeTools.toComplexType(t) );
					case t: Context.error("Glyph-Class expected", Context.currentPos());
				}
			case t: Context.error("Glyph-Class expected", Context.currentPos());
		}
		return null;
	}
	
	static public function buildClass(className:String, glyphPack:Array<String>, glyphModule:String, glyphName:String, superModule:String, superName:String, glyphType:ComplexType):ComplexType
	{		
		var fontStyleNames = glyphName.split("__");
		fontStyleNames.shift();
		
		className += "_" + fontStyleNames.join("_");
		var classPackage = Context.getLocalClass().get().pack;
		
		if (!cache.exists(className))
		{
			cache[className] = true;
			
			var glyphField:Array<String>;
			if (superName == null) glyphField = glyphModule.split(".").concat([glyphName]);
			else glyphField = superModule.split(".").concat([superName]);
			
			var fontName = "Gl3Font";     // TODO -> default
			var fontModule = "peote.text";
			if (fontStyleNames.length > 0) fontName = fontStyleNames.shift();
			fontModule += "." + fontName;
			var fontType = TypeTools.toComplexType(Context.getType(fontModule));
			var fontField = fontModule.split(".").concat([fontName]); // TODO: super-class

			var styleName = "GlyphStyle"; // TODO -> default
			var styleModule = "peote.text";
			if (fontStyleNames.length > 0) {
				var s = fontStyleNames.shift().split("_");
				styleName = s.pop();
				styleModule = s.join(".");
			}
			styleModule += "." + styleName;
			var styleType = TypeTools.toComplexType(Context.getType(styleModule));
			var styleField = styleModule.split(".").concat([styleName]); // TODO: super-class
			
			#if peoteview_debug_macro
			trace('generating Class: '+classPackage.concat([className]).join('.'));	
			
			trace("ClassName:"+className);           // FontProgram_Glyph_Gl3Font_GlyphStyle
			trace("classPackage:" + classPackage);   // [peote,text]	
			
			trace("GlyphPackage:" + glyphPack);  // [peote,text]
			trace("GlyphModule:" + glyphModule); // peote.text.Glyph_Gl3Font_GlyphStyle
			trace("GlyphName:" + glyphName);     // Glyph_Gl3Font_GlyphStyle
			trace("GlyphType:" + glyphType);     // TPath(...)
			trace("GlyphField:" + glyphField);   // [peote,text,Glyph_Gl3Font_GlyphStyle,Glyph_Gl3Font_GlyphStyle]		

			trace("FontModule:" + fontModule); // peote.text.Gl3Font
			trace("FontName:" + fontName);     // Gl3Font			
			trace("FontType:" + fontType);     // TPath(...)
			trace("FontField:" + fontField);   // [peote,text,Gl3Font,Gl3Font]
			
			trace("StyleModule:" + styleModule); // peote.text.GlyphStyle
			trace("StyleName:" + styleName);     // GlyphStyle			
			trace("StyleType:" + styleType);     // TPath(...)
			trace("StyleField:" + styleField);   // [peote,text,GlyphStyle,GlyphStyle]
			#end
			
			// -------------------------------------------------------------------------------------------
			var c = macro		

			class $className extends peote.view.Program
			{
				public var font:$fontType;
				public var fontStyle:peote.text.Gl3FontStyle;
				
				var _buffer:peote.view.Buffer<$glyphType>;
					
				public function new(font:$fontType, fontStyle:peote.text.Gl3FontStyle)
				{
					this.font = font;
					_buffer = new peote.view.Buffer<$glyphType>(100);					
					super(_buffer);					
					setFontStyle(fontStyle); // inject global fontsize and color into shader -> GENERATED
				}
				
				public inline function add(glyph:$glyphType, charcode:Int, x:Int, y:Int):Void {
					glyph.x = x;
					glyph.y = y;
					setCharcode(glyph, charcode);  // -> GENERATED					
					_buffer.addElement(glyph);
				}
								
				public inline function remove(glyph:$glyphType):Void {
					_buffer.removeElement(glyph);
				}
								
				public inline function update(glyph:$glyphType):Void {
					_buffer.updateElement(glyph);
				}
				
			}

			// -------------------------------------------------------------------------------------------
			// -------------------------------------------------------------------------------------------
			
			var glyphStyleHasField = Glyph.GlyphMacro.parseGlyphStyleFields(styleModule);
			//trace("FontProgram: glyphStyleHasField", glyphStyleHasField);
			
			if (fontName == "Gl3Font")
			{
				// ------ generate Function setCharcode -------
				
				var exprBlock = new Array<Expr>();
				if (glyphStyleHasField.width) 
				     exprBlock.push( macro glyph.w = metric.width * glyph.width );
				else exprBlock.push( macro glyph.w = metric.width * fontStyle.width );
				
				if (glyphStyleHasField.height)
				     exprBlock.push( macro glyph.h = metric.height * glyph.height );
				else exprBlock.push( macro glyph.h = metric.height * fontStyle.height );
								
				c.fields.push({
					name: "setCharcode",
					access: [Access.APublic, Access.AInline],
					pos: Context.currentPos(),
					kind: FFun({
						args:[ {name:"glyph", type:macro:$glyphType},
						       {name:"charcode", type:macro:Int},
						],
						//expr: macro $b{ exprBlock },
						expr: macro {
							var range = font.getRange(charcode);
							var metric = range.fontData.getMetric(charcode);
							//trace("glyph"+charcode, range.unit, range.slot, metric);
							
							glyph.unit = range.unit;
							glyph.slot = range.slot;
							
							glyph.tx = metric.u;
							glyph.ty = metric.v;
							glyph.tw = metric.w;
							glyph.th = metric.h;
							
							$b{ exprBlock }
						},
						ret: null
					})
				});
				
				
				// ------ generate Function setFontStyle -------
				
				exprBlock = new Array<Expr>();
				if (glyphStyleHasField.color) 
					exprBlock.push( macro super.setColorFormula("color * smoothstep( "+bold+" - "+sharp+" * fwidth(TEX.r), "+bold+" + "+sharp+" * fwidth(TEX.r), TEX.r)") );
				else
					exprBlock.push( macro super.setColorFormula(Std.string(fontStyle.color.toGLSL()) + " * smoothstep( "+bold+" - "+sharp+" * fwidth(TEX.r), "+bold+" + "+sharp+" * fwidth(TEX.r), TEX.r)") );
				
				c.fields.push({
					name: "setFontStyle",
					access: [Access.APublic],
					pos: Context.currentPos(),
					kind: FFun({
						args:[ {name:"fontStyle", type:macro:peote.text.Gl3FontStyle}
						],
						expr: macro {
							this.fontStyle = fontStyle;
												
							var bold = peote.view.utils.Util.toFloatString(0.5);
							var sharp = peote.view.utils.Util.toFloatString(0.5);
							
							super.setMultiTexture(font.textureCache.textures, "TEX");
							
							$b{ exprBlock }
						},
						ret: null
					})
				});
			
			}

			//Context.defineModule(classPackage.concat([className]).join('.'),[c],Context.getLocalImports());
			Context.defineModule(classPackage.concat([className]).join('.'),[c]);
			//Context.defineType(c);
		}
		return TPath({ pack:classPackage, name:className, params:[] });
	}
}
#end
