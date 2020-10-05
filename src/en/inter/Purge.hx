package en.inter;

import ui.PurgeUi;

class Purge extends Interactive {
    var expired : Bool = false;
    var weapon : Data.Weapons;

    var spawned:Bool = false;

    var l:LevelSeed;
    public function new(x,y, l:LevelSeed) {
        super(x,y);

        this.l = l;
        
        hasColl=false;
        entityVisible = false;

        weight = 1000;
        radius = 1 * Const.GRID;
        spr.anim.registerStateAnim("purge",0,0.2, ()->!expired);
        spr.anim.registerStateAnim("purge_off",0,0.2, ()->expired);
        spr.setCenterRatio(0.5, 1.1);

        var possibleWeapons:Array<Data.WeaponsKind> = [MagicMissile, DevilGun, Shotgun];
        var i = possibleWeapons.length;
        while(--i >= 0) {
            if (Data.weapons.get(possibleWeapons[i]) == Game.ME.weapon)
                possibleWeapons.remove(possibleWeapons[i]);
        }
        weapon = Data.weapons.get(possibleWeapons[M.rand(possibleWeapons.length)]);
    }

    override function activate(by:Hero) {
        super.activate(by);
        if (!expired) {
            new PurgeUi(this);
        }
    }

    public function expire() {
        expired = true;

        Game.ME.weapon = weapon;
        sprSquashX = 1.3;
        sprSquashY = 0.8;

        fx.flashBangS(0xFF0000, 0.85, 2);

        game.camera.bump(0,20);

        game.addMoney(-Data.globals.get(purgePrice).value);

        if (l!=null)
            game.levelLoop.remove(l);
    }

    
    override function update() {
        super.update();
        //d.update(tmod);

        if (!spawned && level.isComplete()) {
            spawned=true;

            fx.flashBangS(0xFF0000, 0.35, 1);

            hasColl=true;
            entityVisible = true;
            
            setSquashX(0.5);
            setSquashY(0.2);
        }
    }
}