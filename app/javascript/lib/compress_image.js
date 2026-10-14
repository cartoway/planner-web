// Copyright © Cartoway
// Shrink mobile stop photos before upload (server caps size / content-type).
// iPhone gallery often yields HEIC/HEIF; Safari can decode → we re-encode as JPEG.

export const PHOTO_MAX_EDGE = 1920
export const PHOTO_JPEG_QUALITY = 0.8
// Keep original when already small enough that recompress rarely helps.
export const PHOTO_SKIP_BELOW_BYTES = 350 * 1024
const IMAGE_NAME_RE = /\.(jpe?g|png|webp|gif|heic|heif)$/i

export function scaleToMaxEdge (width, height, maxEdge = PHOTO_MAX_EDGE) {
  const w = Number(width) || 0
  const h = Number(height) || 0
  if (w <= 0 || h <= 0) return { width: 0, height: 0 }
  const longest = Math.max(w, h)
  if (longest <= maxEdge) return { width: w, height: h }
  const ratio = maxEdge / longest
  return { width: Math.round(w * ratio), height: Math.round(h * ratio) }
}

export function jpegFileName (name) {
  const base = String(name || 'photo').replace(/\.[^.]+$/, '')
  return `${base || 'photo'}.jpg`
}

export function isCompressibleImage (file) {
  if (!file) return false
  const type = String(file.type || '')
  if (type.startsWith('image/')) return true
  // iOS sometimes omits MIME type for HEIC picks from Photos.
  return IMAGE_NAME_RE.test(file.name || '')
}

function canvasToBlob (canvas, type, quality) {
  return new Promise((resolve) => {
    if (canvas.toBlob) {
      canvas.toBlob((blob) => resolve(blob), type, quality)
      return
    }
    try {
      const dataUrl = canvas.toDataURL(type, quality)
      const bin = atob(dataUrl.split(',')[1] || '')
      const bytes = new Uint8Array(bin.length)
      for (let i = 0; i < bin.length; i += 1) bytes[i] = bin.charCodeAt(i)
      resolve(new Blob([bytes], { type }))
    } catch (_err) {
      resolve(null)
    }
  })
}

function loadViaImageElement (file) {
  const url = URL.createObjectURL(file)
  return new Promise((resolve, reject) => {
    const el = new Image()
    el.onload = () => {
      URL.revokeObjectURL(url)
      resolve(el)
    }
    el.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('image load failed'))
    }
    el.src = url
  })
}

async function loadBitmap (file) {
  if (typeof createImageBitmap === 'function') {
    try {
      // Honour EXIF orientation from iPhone JPEGs when the engine supports it.
      return await createImageBitmap(file, { imageOrientation: 'from-image' })
    } catch (_oriented) {
      try {
        return await createImageBitmap(file)
      } catch (_plain) {
        // Fall through: some HEIC builds decode via <img> only.
      }
    }
  }
  return loadViaImageElement(file)
}

export async function compressImage (file, {
  maxEdge = PHOTO_MAX_EDGE,
  quality = PHOTO_JPEG_QUALITY,
  skipBelowBytes = PHOTO_SKIP_BELOW_BYTES,
  mime = 'image/jpeg'
} = {}) {
  if (!isCompressibleImage(file)) return file
  if (file.type === 'image/jpeg' && file.size > 0 && file.size <= skipBelowBytes) return file

  try {
    const bitmap = await loadBitmap(file)
    const sized = scaleToMaxEdge(bitmap.width, bitmap.height, maxEdge)
    if (!sized.width || !sized.height) {
      if (bitmap.close) bitmap.close()
      return file
    }

    const canvas = document.createElement('canvas')
    canvas.width = sized.width
    canvas.height = sized.height
    const ctx = canvas.getContext('2d')
    if (!ctx) {
      if (bitmap.close) bitmap.close()
      return file
    }
    ctx.drawImage(bitmap, 0, 0, sized.width, sized.height)
    if (bitmap.close) bitmap.close()

    const blob = await canvasToBlob(canvas, mime, quality)
    if (!blob || blob.size === 0) return file
    // Prefer original when compression did not shrink and type already matches.
    // Always keep JPEG conversion for HEIC/HEIF (or empty MIME) even if larger.
    if (blob.size >= file.size && file.type === mime) return file

    return new File([blob], jpegFileName(file.name), { type: mime, lastModified: Date.now() })
  } catch (_err) {
    // Decode can fail outside Safari for HEIC; send original (server allows heic/heif).
    return file
  }
}

export function compressImages (files, options) {
  return Promise.all(Array.from(files || []).map((file) => compressImage(file, options)))
}
