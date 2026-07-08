// Sandlot Slugger — vertical-slice batting prototype.
// One mechanic: time your swing to the pitch. Everything else (innings,
// rosters, fielding) is deliberately left out until this loop feels fun.

const FIELD = { width: 800, height: 600 };
const PITCHER_SPOT = { x: 400, y: 130 };
const BATTER_SPOT = { x: 400, y: 480 };

// t is 0 (pitch released) -> 1 (ball reaches the plate). The swing must
// land inside this window of t to make contact.
const ZONE_CENTER = 0.885;
const ZONE_WIDTH = 0.16;

class PlayScene extends Phaser.Scene {
  constructor() {
    super('PlayScene');
  }

  create() {
    this.drawField();

    this.pitcher = this.add.circle(PITCHER_SPOT.x, PITCHER_SPOT.y, 14, 0xffffff)
      .setStrokeStyle(2, 0x222222);
    this.add.rectangle(BATTER_SPOT.x, BATTER_SPOT.y - 10, 30, 60, 0x2b3a67);
    this.bat = this.add.rectangle(BATTER_SPOT.x + 22, BATTER_SPOT.y - 25, 6, 50, 0x8a5a2b)
      .setOrigin(0.5, 1)
      .setAngle(25);

    this.ball = this.add.circle(PITCHER_SPOT.x, PITCHER_SPOT.y, 6, 0xffffff)
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

    const textStyle = { fontFamily: 'Menlo, monospace', fontSize: '20px', color: '#ffffff' };
    this.scoreText = this.add.text(16, 14, '', textStyle);
    this.strikeText = this.add.text(16, 42, '', textStyle);
    this.hintText = this.add.text(FIELD.width / 2, FIELD.height - 30, 'TAP or SPACE to swing', {
      ...textStyle,
      fontSize: '16px',
      color: '#cfd8dc',
    }).setOrigin(0.5);
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
    g.fillStyle(0x8fd3ff, 1).fillRect(0, 0, FIELD.width, 170);
    g.fillStyle(0x2e8b4f, 1).fillRect(0, 170, FIELD.width, FIELD.height - 170);
    g.fillStyle(0x6b4a2f, 1).fillEllipse(PITCHER_SPOT.x, PITCHER_SPOT.y + 20, 90, 40);
    g.fillStyle(0x6b4a2f, 1).fillEllipse(BATTER_SPOT.x, BATTER_SPOT.y + 40, 220, 110);
    g.fillStyle(0xf5f5f5, 1);
    g.fillPoints([
      { x: BATTER_SPOT.x - 12, y: BATTER_SPOT.y + 55 },
      { x: BATTER_SPOT.x + 12, y: BATTER_SPOT.y + 55 },
      { x: BATTER_SPOT.x + 12, y: BATTER_SPOT.y + 65 },
      { x: BATTER_SPOT.x, y: BATTER_SPOT.y + 73 },
      { x: BATTER_SPOT.x - 12, y: BATTER_SPOT.y + 65 },
    ], true);
  }

  startPitch() {
    if (this.resultActive) return;
    this.pitchActive = true;
    this.ball.setVisible(true);
    this.ball.setPosition(PITCHER_SPOT.x, PITCHER_SPOT.y);
    this.ball.setScale(0.4);

    const duration = Phaser.Math.Between(650, 950);
    const curve = Phaser.Math.Between(-40, 40);
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
      },
      onComplete: () => {
        if (this.pitchActive) this.resolvePitch(1, false);
      },
    });
  }

  handleSwing() {
    if (!this.pitchActive || this.resultActive) return;
    this.tweens.add({ targets: this.bat, angle: -70, duration: 90, yoyo: true, ease: 'Quad.Out' });
    this.resolvePitch(this.pitchT.t, true);
  }

  resolvePitch(t, swung) {
    this.pitchActive = false;
    this.pitchTween.stop();
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
    if (accuracy > 0.75) {
      label = 'HOME RUN!';
      color = '#ffd23f';
      scoreAdd = 4;
      this.ball.body.setVelocity(Phaser.Math.Between(-60, 60), -650);
      this.cameras.main.shake(220, 0.01);
    } else if (accuracy > 0.35) {
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
    this.scoreText.setText(`SCORE ${this.score}   HITS ${this.hits}   OUTS ${this.outsTotal}`);
    this.strikeText.setText(`STRIKES: ${'●'.repeat(this.strikes)}${'○'.repeat(3 - this.strikes)}`);
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
