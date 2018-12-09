package elements;

import peote.view.Color;
import peote.view.Element;

class ElementSimple implements Element
{
	@posX public var x:Int=0; // signed 2 bytes integer
	@posY public var y:Int=0; // signed 2 bytes integer
	
	@sizeX public var w:Int=100;
	@sizeY public var h:Int=100;
	
	@color public var c:Color = 0xff0000ff;
	// TODO
	//@color("add") public var cAdd:Color = 0xff0000ff;
	//@color("shift") public var cAdd:Color = 0xff0000ff;
	
	@zIndex public var z:Int = 0;

	//@texUnit() public var unit:Int;  // unit for all other Layers (max 255)
	@texUnit("color") public var unitColor:Int=0;  //  unit for "color" Layers only
	@texUnit("alpha","mask") public var unitAlphaMask:Int;  //  unit for "alpha" and "mask" Layers

	@texSlot("color") public var slot:Int;  // unsigned 2 bytes integer

	@texTile() public var tile:Int;  // unsigned 2 bytes integer
	@texTile("color", "mask") public var tileColor:Int;  // unsigned 2 bytes integer

	// texture padding from left, right, top or bottom inside Texture, Slots or Tile  
	@texX("color") public var tx:Int;
	@texY("color") public var ty:Int;
	@texW("color") public var tw:Int=256;
	//@texH("color") public var th:Int=512;
	
	//TODO:
	//@texOffsetX("color") public var txOffset:Int;
	//@texOffsetY("color") public var tyOffset:Int;
	
	
	public function new(positionX:Int=0, positionY:Int=0, width:Int=100, height:Int=100, c:Int=0xFF0000FF )
	{
		this.x = positionX;
		this.y = positionY;
		this.w = width;
		this.h = height;
		this.c = c;
	}


}
