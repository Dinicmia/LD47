import h2d.Bitmap;
import h2d.Graphics;
import en.Hero;
import ui.EndWindow;
import h2d.col.Point;
import h2d.Interactive;
import dn.Process;
import hxd.Key;

class Game extends Process {
	public static var ME : Game;

	/** Game controller (pad or keyboard) **/
	public var ca : dn.heaps.Controller.ControllerAccess;

	/** Particles **/
	public var fx : Fx;

	/** Basic viewport control **/
	public var camera : Camera;

	/** Container of all visual game objects. Ths wrapper is moved around by Camera. **/
	public var scroller : h2d.Layers;

	/** Level data **/
	public var level : Level;

	/** UI **/
	public var hud : ui.Hud;

	/** Slow mo internal values**/
	var curGameSpeed = 1.0;
	var slowMos : Map<String, { id:String, t:Float, f:Float }> = new Map();

	/** LEd world data **/
	public var world : World;

	var levelToLoad : World.World_Level;
	public var levelLoop:Array<World.World_Level>;
	public var levelIndex:Int = 0;

	var mask : h2d.Bitmap;

	public var money:Int = 12;

	// Player stuff
	public var hero:Hero;
	public var playerLife: Int;
	public var playerMaxLife: Int;

	public function new() {
		super(Main.ME);
		ME = this;

		ca = Main.ME.controller.createAccess("game");
		ca.setLeftDeadZone(0.2);
		ca.setRightDeadZone(0.2);
		createRootInLayers(Main.ME.root, Const.DP_BG);

		scroller = new h2d.Layers();
		root.add(scroller, Const.DP_BG);
		scroller.filter = new h2d.filter.ColorMatrix(); // force rendering for pixel perfect

		playerLife = playerMaxLife = Data.globals.get(playerHp).value;

		world = new World();
		camera = new Camera();
		fx = new Fx();
		hud = new ui.Hud();
		levelLoop = [world.all_levels.ScrollChamber];
		
		mask = new h2d.Bitmap(h2d.Tile.fromColor(0x0));
		root.add(mask, Const.DP_UI);

		startLevel(levelLoop[0]);

		Process.resizeAll();
		//trace(Lang.t._("Game is ready."));
	}

	/**
		Called when the CastleDB changes on the disk, if hot-reloading is enabled in Boot.hx
	**/
	public function onCdbReload() {
	}

	override function onResize() {
		super.onResize();
		scroller.setScale(Const.SCALE);

		mask.scaleX = w();
		mask.scaleY = h();
	}


	function gc() {
		if( Entity.GC==null || Entity.GC.length==0 )
			return;

		for(e in Entity.GC)
			e.dispose();
		Entity.GC = [];
	}

	override function onDispose() {
		super.onDispose();

		fx.destroy();
		for(e in Entity.ALL)
			e.destroy();
		gc();
	}


	/**
		Start a cumulative slow-motion effect that will affect `tmod` value in this Process
		and its children.

		@param sec Realtime second duration of this slowmo
		@param speedFactor Cumulative multiplier to the Process `tmod`
	**/
	public function addSlowMo(id:String, sec:Float, speedFactor=0.3) {
		if( slowMos.exists(id) ) {
			var s = slowMos.get(id);
			s.f = speedFactor;
			s.t = M.fmax(s.t, sec);
		}
		else
			slowMos.set(id, { id:id, t:sec, f:speedFactor });
	}


	function updateSlowMos() {
		// Timeout active slow-mos
		for(s in slowMos) {
			s.t -= utmod * 1/Const.FPS;
			if( s.t<=0 )
				slowMos.remove(s.id);
		}

		// Update game speed
		var targetGameSpeed = 1.0;
		for(s in slowMos)
			targetGameSpeed*=s.f;
		curGameSpeed += (targetGameSpeed-curGameSpeed) * (targetGameSpeed>curGameSpeed ? 0.2 : 0.6);

		if( M.fabs(curGameSpeed-targetGameSpeed)<=0.001 )
			curGameSpeed = targetGameSpeed;
	}


	/**
		Pause briefly the game for 1 frame: very useful for impactful moments,
		like when hitting an opponent in Street Fighter ;)
	**/
	public inline function stopFrame() {
		ucd.setS("stopFrame", 0.2);
	}

	override function preUpdate() {
		super.preUpdate();
		
		for(e in Entity.ALL) if( !e.destroyed ) e.preUpdate();
	}

	override function postUpdate() {
		super.postUpdate();


		for(e in Entity.ALL) if( !e.destroyed ) e.postUpdate();
		for(e in Entity.ALL) if( !e.destroyed ) e.finalUpdate();
		gc();

		// Update slow-motions
		updateSlowMos();
		baseTimeMul = ( 0.2 + 0.8*curGameSpeed ) * ( ucd.has("stopFrame") ? 0.3 : 1 );
		Assets.tiles.tmod = tmod;
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.fixedUpdate();
	}

	override function update() {
		super.update();

		// Z sort
		if( !cd.hasSetS("zsort",0.1) )
			Entity.ALL.sort( function(a,b) return Reflect.compare(a.z, b.z) );

		for(e in Entity.ALL) {
			scroller.over(e.spr);
			if( !e.destroyed ) e.update();
		}

		if (levelToLoad!=null)
			startLevel(levelToLoad);

		if( !ui.Console.ME.isActive() && !ui.Modal.hasAny() ) {
			#if hl
			// Exit
			if( ca.isKeyboardPressed(Key.ESCAPE) )
				if( !cd.hasSetS("exitWarn",3) )
					trace(Lang.t._("Press ESCAPE again to exit."));
				else
					hxd.System.exit();
			#end

			// Restart
			if( ca.selectPressed())
				Main.ME.startGame();
		}
	}

	public function loadNextLevel() {
		levelIndex++;
		if (levelIndex>=levelLoop.length)
			levelIndex = 0;

		levelToLoad = levelLoop[levelIndex];
	}

	function startLevel(l : World.World_Level) {
		trace("Loading new level...");
		for(e in Entity.ALL)
			e.destroy();
		gc();
		fx.clear();
		if( level!=null )
			level.destroy();

		level = new Level(l);
		
		Process.resizeAll();

		levelToLoad=null;
		mask.visible=true;
		tw.createS(mask.alpha, 1>0, 0.6).end(()->mask.visible=false);
	}

	public function addMoney(amount:Int) {
		money += amount;
		hud.setMoney(money);
		amount>0 ? hud.blinkWhite() : hud.blinkRed();
	}

	public function win() {
		new EndWindow(Data.text.get(victory).text);
	}
}

