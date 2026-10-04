// Round avatar (DESIGN.md 6.11): the profile photo when there is one, else the name's first letter on
// brand_accent_soft, else the person glyph. Follows ProfilePhoto changes by itself. `photo: false` forces the
// letter, e.g. where the user switched the photo off for the emergency card.

import { ProfilePhoto } from '../data/ProfilePhoto';

@ComponentV2
export struct ProfileAvatar {
  @Param side: number = 56;
  @Param name: string = '';
  @Param photo: boolean = true;
  @Local uri: string = '';
  private stop: () => void = () => {
  };

  aboutToAppear(): void {
    this.uri = ProfilePhoto.uri();
    this.stop = ProfilePhoto.onChange((u: string) => {
      this.uri = u;
    });
  }

  aboutToDisappear(): void {
    this.stop();
  }

  build() {
    Stack() {
      if (this.photo && this.uri !== '') {
        Image(this.uri)
          .width(this.side)
          .height(this.side)
          .objectFit(ImageFit.Cover)
          .accessibilityLevel('no')
      } else if (this.name.trim().length > 0) {
        Text(this.name.trim().charAt(0).toUpperCase())
          .fontSize(Math.round(this.side * 0.4))
          .fontWeight(800)
          .fontColor($r('app.color.brand_text'))
      } else {
        Image($r('app.media.ic_user'))
          .width(Math.round(this.side * 0.46))
          .height(Math.round(this.side * 0.46))
          .fillColor($r('app.color.brand_text'))
      }
    }
    .width(this.side)
    .height(this.side)
    .borderRadius(this.side / 2)
    .clip(true)
    .backgroundColor($r('app.color.brand_accent_soft'))
  }
}
