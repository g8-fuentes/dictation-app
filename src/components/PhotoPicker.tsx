import { useEffect, useRef, useState } from 'react'
import { Icon } from './Icon'

/** Camera or gallery, with a preview. */
export function PhotoPicker({
  step,
  title,
  hint,
  file,
  onChange,
}: {
  step?: string
  title: string
  hint: string
  file: File | null
  onChange: (f: File | null) => void
}) {
  const camera = useRef<HTMLInputElement>(null)
  const gallery = useRef<HTMLInputElement>(null)
  const [url, setUrl] = useState<string>()

  useEffect(() => {
    if (!file) return setUrl(undefined)
    const u = URL.createObjectURL(file)
    setUrl(u)
    return () => URL.revokeObjectURL(u)
  }, [file])

  const take = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    if (f) onChange(f)
    e.target.value = ''
  }

  return (
    <section className="card slot">
      <div className="slot-head">
        {step && <span className={`step ${file ? 'done' : ''}`}>{file ? <Icon name="check" size={16} /> : step}</span>}
        <h2>{title}</h2>
        {file && (
          <button className="icon-btn" aria-label="Remover foto" onClick={() => onChange(null)}>
            <Icon name="close" />
          </button>
        )}
      </div>
      {url ? (
        <img className="preview" src={url} alt={title} />
      ) : (
        <div className="placeholder">
          <Icon name="image" size={30} />
          <span>{hint}</span>
        </div>
      )}
      <div className="row">
        <button className="btn tonal" onClick={() => camera.current?.click()}>
          <Icon name="camera" size={20} /> Câmera
        </button>
        <button className="btn outline" onClick={() => gallery.current?.click()}>
          <Icon name="image" size={20} /> Galeria
        </button>
      </div>
      <input ref={camera} type="file" accept="image/*" capture="environment" hidden onChange={take} data-testid={`${title}-camera`} />
      <input ref={gallery} type="file" accept="image/*" hidden onChange={take} data-testid={`${title}-gallery`} />
    </section>
  )
}
