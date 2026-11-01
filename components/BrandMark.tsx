/** One editable SVG asset. Adjacent live text supplies the accessible name. */
export default function BrandMark({asImage=false}:{asImage?:boolean}) {
  return asImage
    ? <img className="brand-mark" src="/brand/mohammadstyle-mark.svg" width={64} height={64} alt="" aria-hidden="true"/>
    : <span className="brand-mark" aria-hidden="true"/>;
}
