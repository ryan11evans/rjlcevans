// Sandlot Slugger — vertical-slice batting prototype.
// One mechanic: time your swing to the pitch. Everything else (innings,
// rosters, fielding) is deliberately left out until this loop feels fun.

const FIELD = { width: 800, height: 600 };
const PITCHER_SPOT = { x: 400, y: 130 };
const BATTER_SPOT = { x: 400, y: 480 };

// t is 0 (pitch released) -> 1 (ball reaches the plate). The swing must
// land inside this window of t to make contact. The meter bar below the
// plate telegraphs this window so hitting it is about reading the meter,
// not guessing the ball's speed.
const ZONE_CENTER = 0.8;
const ZONE_WIDTH = 0.3;

const METER = { x: 150, y: 566, width: 500, height: 16 };

class PlayScene extends Phaser.Scene {
  constructor() {
    super('PlayScene');
  }

  create() {
    this.drawField();
    this.drawBatter();
    this.drawMeter();

    this.pitcher = this.add.circle(PITCHER_SPOT.x, PITCHER_SPOT.y, 14, 0xffffff)
      .setStrokeStyle(2, 0x333333);

    this.ballShadow = this.add.ellipse(BATTER_SPOT.x, BATTER_SPOT.y + 8, 26, 10, 0x000000, 0.25);
    this.ball = this.add.circle(PITCHER_SPOT.x, PITCHER_SPOT.y, 7, 0xffffff)
      .setStrokeStyle(1, 0x333333)
      .setVisible(false);
    this.physics.add.existing(this.ball);
    this.ball.body.setAllowGravity(false);
    this.ball.body.setCollideWorldBounds(false);

    this.score = 0;
    this.hits = 0;
    this.strikes = 0;
    this.outsTotal = 0;
    this.pitchActive = false;
    this.resultActive = false;

    this.hudPanel = this.add.rectangle(8, 8, 236, 62, 0x0a1b12, 0.55)
      .setOrigin(0, 0)
      .setStrokeStyle(1, 0xffffff, 0.15);
    const textStyle = { fontFamily: 'Menlo, monospace', fontSize: '18px', color: '#ffffff' };
    this.scoreText = this.add.text(18, 16, '', textStyle);
    this.strikeText = this.add.text(18, 42, '', textStyle);
    this.messageText = this.add.text(FIELD.width / 2, 300, '', {
      fontFamily: 'Menlo, monospace',
      fontSize: '40px',
      fontStyle: 'bold',
      color: '#ffffff',
      stroke: '#000000',
      strokeThickness: 6,
    }).setOrigin(0.5).setAlpha(0);

    this.updateHud();

    this.input.on('pointerdown', () => this.handleSwing());
    this.input.keyboard.on('keydown-SPACE', () => this.handleSwing());

    this.time.delayedCall(900, () => this.startPitch());
  }

  drawField() {
    const g = this.add.graphics();

    g.fillGradientStyle(0x8fd3ff, 0x8fd3ff, 0xd8ecff, 0xd8ecff, 1);
    g.fillRect(0, 0, FIELD.width, 170);

    const stripes = 7;
    const stripeH = (FIELD.height - 170) / stripes;
    for (let i = 0; i < stripes; i++) {
      g.fillStyle(i % 2 === 0 ? 0x2e8b4f : 0x2a9954, 1);
      g.fillRect(0, 170 + i * stripeH, FIELD.width, stripeH + 1);
    }

    g.fillStyle(0x7a5636, 1).fillEllipse(PITCHER_SPOT.x, PITCHER_SPOT.y + 20, 100, 44);
    g.fillStyle(0x8a6440, 1).fillEllipse(PITCHER_SPOT.x, PITCHER_SPOT.y + 16, 80, 32);

    g.fillStyle(0x7a5636, 1).fillEllipse(BATTER_SPOT.x, BATTER_SPOT.y + 45, 260, 130);
    g.fillStyle(0x8a6440, 1).fillEllipse(BATTER_SPOT.x, BATTER_SPOT.y + 40, 230, 108);

    g.fillStyle(0xf5f5f5, 1);
    g.fillPoints([
      { x: BATTER_SPOT.x - 12, y: BATTER_SPOT.y + 55 },
      { x: BATTER_SPOT.x + 12, y: BATTER_SPOT.y + 55 },
      { x: BATTER_SPOT.x + 12, y: BATTER_SPOT.y + 65 },
      { x: BATTER_SPOT.x, y: BATTER_SPOT.y + 73 },
      { x: BATTER_SPOT.x - 12, y: BATTER_SPOT.y + 65 },
    ], true);
  }

  drawBatter() {
    const x = BATTER_SPOT.x;
    const groundY = BATTER_SPOT.y;

    this.add.rectangle(x - 9, groundY - 15, 9, 32, 0x1c2541);
    this.add.rectangle(x + 9, groundY - 15, 9, 32, 0x1c2541);
    this.add.rectangle(x, groundY - 55, 34, 46, 0xd7263d).setStrokeStyle(2, 0xa81a2c);
    this.add.circle(x, groundY - 86, 14, 0xf0c090).setStrokeStyle(1, 0xc99a68);
    this.add.rectangle(x - 1, groundY - 97, 28, 11, 0x1c2541).setOrigin(0.5, 0.5);
    this.add.rectangle(x + 12, groundY - 96, 12, 5, 0x1c2541);

    this.bat = this.add.rectangle(x + 20, groundY - 68, 6, 46, 0x9c6b3a)
      .setOrigin(0.5, 1)
      .setAngle(30);
  }

  drawMeter() {
    const { x, y, width, height } = METER;
    const label = this.add.text(x + width / 2, y - 22, 'SWING WHEN THE MARKER HITS GOLD', {
      fontFamily: 'Menlo, monospace',
      fontSize: '12px',
      color: '#f2f6f8',
    }).setOrigin(0.5);
    this.add.rectangle(label.x, label.y, label.width + 14, label.height + 8, 0x0a1b12, 0.75);
    this.children.bringToTop(label);

    this.add.rectangle(x + width / 2, y, width, height, 0x0a1b12, 0.85)
      .setStrokeStyle(2, 0xffffff, 0.4);

    const zoneStart = ZONE_CENTER - ZONE_WIDTH / 2;
    const zoneW = ZONE_WIDTH * width;
    this.add.rectangle(x + zoneStart * width + zoneW / 2, y, zoneW, height, 0xffd23f, 0.9)
      .setStrokeStyle(1, 0x8a6d1f);

    this.meterMarker = this.add.rectangle(x, y, 5, height + 12, 0xffffff)
      .setStrokeStyle(1, 0x000000)
      .setVisible(false);
  }

  startPitch() {
    if (this.resultActive) return;
    this.pitchActive = true;
    this.ball.setVisible(true);
    this.ball.setPosition(PITCHER_SPOT.x, PITCHER_SPOT.y);
    this.ball.setScale(0.4);
    this.meterMarker.setVisible(true);
    this.meterMarker.setPosition(METER.x, METER.y);

    const duration = Phaser.Math.Between(1000, 1400);
    const curve = Phaser.Math.Between(-35, 35);
    this.pitchT = { t: 0 };
    this.pitchTween = this.tweens.add({
      targets: this.pitchT,
      t: 1,
      duration,
      ease: 'Linear',
      onUpdate: () => {
        const t = this.pitchT.t;
        const x = Phaser.Math.Linear(PITCHER_SPOT.x, BATTER_SPOT.x, t) + Math.sin(t * Math.PI) * curve;
        const y = Phaser.Math.Linear(PITCHER_SPOT.y, BATTER_SPOT.y, t);
        this.ball.setPosition(x, y);
        this.ball.setScale(Phaser.Math.Linear(0.4, 1.3, t));
        this.meterMarker.x = METER.x + t * METER.width;
      },
      onComplete: () => {
        if (this.pitchActive) this.resolvePitch(1, false);
      },
    });
  }

  handleSwing() {
    if (!this.pitchActive || this.resultActive) return;
    this.tweens.add({ targets: this.bat, angle: -95, duration: 110, yoyo: true, ease: 'Quad.Out' });
    this.resolvePitch(this.pitchT.t, true);
  }

  resolvePitch(t, swung) {
    this.pitchActive = false;
    this.pitchTween.stop();
    this.meterMarker.setVisible(false);
    const inZone = swung && Math.abs(t - ZONE_CENTER) <= ZONE_WIDTH / 2;
    if (inZone) {
      const accuracy = 1 - Math.abs(t - ZONE_CENTER) / (ZONE_WIDTH / 2);
      this.contact(accuracy);
    } else {
      this.strike(swung);
    }
  }

  contact(accuracy) {
    this.resultActive = true;
    this.ball.body.setAllowGravity(true);

    let label, color, scoreAdd;
    if (accuracy > 0.7) {
      label = 'HOME RUN!';
      color = '#ffd23f';
      scoreAdd = 4;
      this.ball.body.setVelocity(Phaser.Math.Between(-60, 60), -650);
      this.cameras.main.shake(220, 0.01);
    } else if (accuracy > 0.3) {
      label = 'BASE HIT!';
      color = '#7cfc9a';
      scoreAdd = 1;
      this.ball.body.setVelocity(Phaser.Math.Between(-200, 200), -300);
      this.cameras.main.shake(120, 0.005);
    } else {
      label = 'FOUL BALL';
      color = '#ffffff';
      scoreAdd = 0;
      this.ball.body.setVelocity(Phaser.Math.Between(-350, 350), -150);
    }

    this.score += scoreAdd;
    if (scoreAdd > 0) this.hits++;
    this.strikes = 0;
    this.updateHud();
    this.flashMessage(label, color);
    this.time.delayedCall(1300, () => this.endResult());
  }

  strike(swung) {
    this.resultActive = true;
    this.ball.setVisible(false);
    this.strikes++;

    if (this.strikes >= 3) {
      this.strikes = 0;
      this.outsTotal++;
      this.flashMessage('STRIKE 3 - OUT!', '#ff5c5c');
    } else {
      this.flashMessage(swung ? 'SWING AND MISS' : 'STRIKE!', '#ff5c5c');
    }
    this.updateHud();
    this.time.delayedCall(1000, () => this.endResult());
  }

  flashMessage(text, color) {
    this.messageText.setText(text).setColor(color).setAlpha(1).setScale(0.6);
    this.tweens.add({ targets: this.messageText, scale: 1, duration: 200, ease: 'Back.Out' });
    this.tweens.add({ targets: this.messageText, alpha: 0, delay: 900, duration: 300 });
  }

  endResult() {
    this.resultActive = false;
    this.ball.setVisible(false);
    this.ball.body.setVelocity(0, 0);
    this.ball.body.setAllowGravity(false);
    this.time.delayedCall(500, () => this.startPitch());
  }

  updateHud() {
    this.scoreText.setText(`SCORE ${this.score}   HITS ${this.hits}`);
    this.strikeText.setText(`OUTS ${this.outsTotal}   ${'●'.repeat(this.strikes)}${'○'.repeat(3 - this.strikes)}`);
  }
}

window.game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game-container',
  width: FIELD.width,
  height: FIELD.height,
  backgroundColor: '#1e6b3a',
  physics: {
    default: 'arcade',
    arcade: { gravity: { y: 900 }, debug: false },
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [PlayScene],
});
