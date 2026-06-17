import imageCompression from 'browser-image-compression';

export interface ImageResizeOptions {
    maxWidthOrHeight?: number;
    maxWidth?: number;
    maxHeight?: number;
    fileType?: string;
}

export async function compressAndResizeImage(
    file: File,
    options: ImageResizeOptions = {}
): Promise<File> {
    const maxWidth = options.maxWidth || parseInt(import.meta.env.VITE_IMAGE_MAX_WIDTH, 10) || 1536;
    const compressionOptions = {
        maxWidthOrHeight: maxWidth,
        useWebWorker: true,
        fileType: options.fileType || 'image/webp',
    };

    try {
        const compressedFile = await imageCompression(file, compressionOptions);
        return compressedFile;
    } catch (error) {
        console.error("Image compression failed:", error);
        throw error;
    }
}