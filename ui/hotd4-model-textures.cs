using System;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Hotd4Models
{
    internal enum TextureAlpha { Opaque, Blend, Cutout }

    internal sealed class TextureEntry
    {
        internal string Path, Name;
        internal long Offset;
        internal int Length;

        internal BitmapSource Load(TextureAlpha alpha, string hdPack, bool enhance, out bool replaced)
        {
            byte[] data;
            using (var reader = new BinaryReader(File.OpenRead(Path)))
            {
                reader.BaseStream.Position = Offset;
                data = reader.ReadBytes(Length);
            }
            BitmapSource original = Dds.Decode(data, alpha, hdPack, out replaced);
            if (replaced || !enhance) return original;
            BitmapSource enhanced = CharacterTexture.Enhance(original);
            replaced = enhanced != original;
            return enhanced;
        }
    }

    internal static class CharacterTexture
    {
        internal static BitmapSource Enhance(BitmapSource original)
        {
            int largest = Math.Max(original.PixelWidth, original.PixelHeight);
            if (Math.Min(original.PixelWidth, original.PixelHeight) < 16 || largest > 1024) return original;
            int scale = largest <= 512 ? 4 : 2;
            int width = original.PixelWidth * scale, height = original.PixelHeight * scale;
            var drawing = new DrawingVisual();
            RenderOptions.SetBitmapScalingMode(drawing, BitmapScalingMode.HighQuality);
            using (DrawingContext context = drawing.RenderOpen())
                context.DrawImage(original, new Rect(0, 0, width, height));

            var resized = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            resized.Render(drawing);
            int stride = width * 4;
            byte[] pixels = new byte[stride * height];
            resized.CopyPixels(pixels, stride, 0);
            byte[] result = (byte[])pixels.Clone();

            // Sharpen the existing luminance edges without changing the alpha or palette.
            // Sample at the original texel spacing and leave cutout edges alone.
            int dx = scale * 4, dy = scale * stride;
            for (int y = scale; y < height - scale; ++y)
            {
                for (int x = scale; x < width - scale; ++x)
                {
                    int p = y * stride + x * 4;
                    if (pixels[p + 3] != 255 || pixels[p + 3 - dx] != 255 || pixels[p + 3 + dx] != 255 ||
                        pixels[p + 3 - dy] != 255 || pixels[p + 3 + dy] != 255) continue;
                    int neighbors = Luminance(pixels, p - dx) + Luminance(pixels, p + dx) +
                                    Luminance(pixels, p - dy) + Luminance(pixels, p + dy);
                    int detail = Luminance(pixels, p) - ((neighbors + 2) >> 2);
                    if (Math.Abs(detail) < 3) continue;
                    int contrast = Math.Max(-24, Math.Min(24, detail * 5 / 4));
                    for (int channel = 0; channel < 3; ++channel)
                        result[p + channel] = (byte)Math.Max(0, Math.Min(255, pixels[p + channel] + contrast));
                }
            }
            BitmapSource bitmap = BitmapSource.Create(width, height, 96, 96, PixelFormats.Pbgra32, null, result, stride);
            bitmap.Freeze();
            return bitmap;
        }

        private static int Luminance(byte[] pixels, int p)
        {
            return (19 * pixels[p] + 183 * pixels[p + 1] + 54 * pixels[p + 2] + 128) >> 8;
        }
    }

    internal static class Dds
    {
        private const uint Dxt1 = 0x31545844, Dxt3 = 0x33545844, Dxt5 = 0x35545844;
        private static uint U32(byte[] data, int offset) { return BitConverter.ToUInt32(data, offset); }

        // Matches the original compressed base levels listed in hotd4_hd_textures.c.
        private static readonly HdReplacement[] replacements = {
            new HdReplacement("stage01_a00-33", 0x80dbb159eb446194UL, 128, 256, Dxt1, 4),
            new HdReplacement("stage01_a00-50", 0xc4a9657e0a7e112cUL, 256, 256, Dxt1, 4),
            new HdReplacement("stage01_a00-57", 0x42a23cdfe45e0d61UL, 256, 256, Dxt5, 4),
            new HdReplacement("stage01_a00-58", 0x3797ed16e1572498UL, 256, 256, Dxt5, 4),
            new HdReplacement("stage01_a00-69", 0x717f01735c5caeefUL, 128, 128, Dxt5, 4),
            new HdReplacement("stage01_a00-71", 0x90976b415216bedfUL, 128, 128, Dxt1, 4),
            new HdReplacement("stage01_a00-79", 0xee1e8eb7abc9f693UL, 512, 512, Dxt1, 2),
            new HdReplacement("zn04a-4", 0xa1f5b5746b44ab28UL, 1024, 1024, Dxt1, 2),
            new HdReplacement("zn04a-13", 0x8fcb2da4188a667cUL, 1024, 1024, Dxt1, 2)
        };

        private sealed class HdReplacement
        {
            internal readonly string File;
            internal readonly ulong Hash;
            internal readonly int Width, Height, Scale;
            internal readonly uint Format;

            internal HdReplacement(string file, ulong hash, int width, int height, uint format, int scale)
            {
                File = file + ".bc"; Hash = hash; Width = width; Height = height; Format = format; Scale = scale;
            }
        }

        private static int BlockBytes(int width, int height, uint format)
        {
            return ((width + 3) / 4) * ((height + 3) / 4) * (format == Dxt1 ? 8 : 16);
        }

        private static byte[] ReadReplacement(string pack, byte[] dds, int width, int height, uint format, out int scale)
        {
            scale = 1;
            ulong? hash = null;
            foreach (HdReplacement entry in replacements)
            {
                if (entry.Width != width || entry.Height != height || entry.Format != format) continue;
                if (!hash.HasValue)
                {
                    int end = 128 + BlockBytes(width, height, format);
                    if (end > dds.Length) return null;
                    ulong value = 14695981039346656037UL;
                    for (int i = 128; i < end; ++i)
                        value = unchecked((value ^ dds[i]) * 1099511628211UL);
                    hash = value;
                }
                if (hash.Value != entry.Hash) continue;

                int w = width * entry.Scale, h = height * entry.Scale;
                int topBytes = BlockBytes(w, h, format);
                int totalBytes = topBytes;
                while (w > 1 || h > 1)
                {
                    w = Math.Max(1, w / 2);
                    h = Math.Max(1, h / 2);
                    totalBytes += BlockBytes(w, h, format);
                }
                try
                {
                    using (var reader = new BinaryReader(File.OpenRead(Path.Combine(pack, entry.File))))
                    {
                        if (reader.BaseStream.Length != totalBytes) return null;
                        byte[] data = reader.ReadBytes(topBytes);
                        if (data.Length != topBytes) return null;
                        scale = entry.Scale;
                        return data;
                    }
                }
                catch (IOException) { return null; }
                catch (UnauthorizedAccessException) { return null; }
            }
            return null;
        }

        internal static BitmapSource Decode(byte[] data, TextureAlpha alpha, string hdPack, out bool replaced)
        {
            replaced = false;
            if (data.Length < 128 || U32(data, 0) != 0x20534444 || U32(data, 4) != 124 || U32(data, 76) != 32)
                throw new InvalidDataException("Invalid DDS header.");
            uint h = U32(data, 12), w = U32(data, 16);
            if (w == 0 || h == 0 || w > 8192 || h > 8192 || (long)w * h > 16777216)
                throw new InvalidDataException("Unsupported DDS dimensions.");
            int width = (int)w, height = (int)h;
            uint format = U32(data, 84);
            int scale = 1;
            byte[] hd = String.IsNullOrEmpty(hdPack) ? null : ReadReplacement(hdPack, data, width, height, format, out scale);
            replaced = hd != null;
            width *= scale;
            height *= scale;
            byte[] pixels = new byte[checked(width * height * 4)];
            if (format == Dxt1 || format == Dxt3 || format == Dxt5)
                DecodeBlocks(hd ?? data, replaced ? 0 : 128, pixels, width, height, format, alpha);
            else if ((U32(data, 80) & 4) == 0)
                DecodePixels(data, pixels, width, height, alpha);
            else
                throw new InvalidDataException("Unsupported DDS compression.");
            BitmapSource bitmap = BitmapSource.Create(width, height, 96, 96, PixelFormats.Bgra32, null, pixels, width * 4);
            bitmap.Freeze();
            return bitmap;
        }

        private static byte ResolveAlpha(int value, TextureAlpha alpha)
        {
            if (alpha == TextureAlpha.Opaque) return 255;
            if (alpha == TextureAlpha.Cutout) return value >= 128 ? (byte)255 : (byte)0;
            return (byte)value;
        }

        private static void ReadColor565(ushort value, byte[] palette, int slot)
        {
            int offset = slot * 4;
            int b = value & 31, g = (value >> 5) & 63, r = value >> 11;
            palette[offset] = (byte)((b << 3) | (b >> 2));
            palette[offset + 1] = (byte)((g << 2) | (g >> 4));
            palette[offset + 2] = (byte)((r << 3) | (r >> 2));
            palette[offset + 3] = 255;
        }

        private static void ColorPalette(byte[] data, int offset, byte[] palette, bool dxt1)
        {
            ushort first = BitConverter.ToUInt16(data, offset);
            ushort second = BitConverter.ToUInt16(data, offset + 2);
            ReadColor565(first, palette, 0);
            ReadColor565(second, palette, 1);
            bool transparent = dxt1 && first <= second;
            for (int i = 0; i < 3; ++i)
            {
                int a = palette[i], b = palette[4 + i];
                palette[8 + i] = (byte)(transparent ? (a + b) / 2 : (2 * a + b) / 3);
                palette[12 + i] = (byte)(transparent ? 0 : (a + 2 * b) / 3);
            }
            palette[11] = 255;
            palette[15] = transparent ? (byte)0 : (byte)255;
        }

        private static void Dxt5Alpha(byte[] data, int offset, byte[] palette)
        {
            int a = data[offset], b = data[offset + 1];
            palette[0] = (byte)a; palette[1] = (byte)b;
            int divide = a > b ? 7 : 5;
            for (int i = 1; i < divide; ++i)
                palette[i + 1] = (byte)(((divide - i) * a + i * b) / divide);
            if (divide == 5) { palette[6] = 0; palette[7] = 255; }
        }

        private static void DecodeBlocks(byte[] data, int offset, byte[] pixels, int width, int height, uint format, TextureAlpha alpha)
        {
            int bytes = format == Dxt1 ? 8 : 16;
            long required = (long)offset + BlockBytes(width, height, format);
            if (required > data.Length) throw new InvalidDataException("Truncated DDS blocks.");
            byte[] colors = new byte[16], alphas = new byte[8];
            for (int y = 0; y < height; y += 4)
            {
                for (int x = 0; x < width; x += 4, offset += bytes)
                {
                    int colorOffset = offset + bytes - 8;
                    ColorPalette(data, colorOffset, colors, format == Dxt1);
                    uint colorBits = U32(data, colorOffset + 4);
                    ulong alphaBits = 0;
                    if (format == Dxt3) alphaBits = BitConverter.ToUInt64(data, offset);
                    if (format == Dxt5)
                    {
                        Dxt5Alpha(data, offset, alphas);
                        alphaBits = BitConverter.ToUInt64(data, offset) >> 16;
                    }
                    for (int row = 0; row < 4 && y + row < height; ++row)
                    {
                        for (int col = 0; col < 4 && x + col < width; ++col)
                        {
                            int i = row * 4 + col;
                            int color = (int)((colorBits >> (i * 2)) & 3) * 4;
                            int opacity = colors[color + 3];
                            if (format == Dxt3) opacity = (int)((alphaBits >> (i * 4)) & 15) * 17;
                            if (format == Dxt5) opacity = alphas[(int)((alphaBits >> (i * 3)) & 7)];
                            int pos = ((y + row) * width + x + col) * 4;
                            pixels[pos] = colors[color]; pixels[pos + 1] = colors[color + 1];
                            pixels[pos + 2] = colors[color + 2]; pixels[pos + 3] = ResolveAlpha(opacity, alpha);
                        }
                    }
                }
            }
        }

        private struct Channel
        {
            internal uint Mask, Max;
            internal int Shift;
            internal Channel(uint mask)
            {
                Mask = mask; Shift = 0;
                if (mask != 0)
                    while ((mask & 1) == 0) { mask >>= 1; ++Shift; }
                Max = mask;
            }
            internal byte Read(uint value, byte fallback)
            {
                if (Mask == 0) return fallback;
                return (byte)(((ulong)((value & Mask) >> Shift) * 255u + Max / 2) / Max);
            }
        }

        private static void DecodePixels(byte[] data, byte[] pixels, int width, int height, TextureAlpha alpha)
        {
            uint bits = U32(data, 88);
            if (bits != 8 && bits != 16 && bits != 24 && bits != 32)
                throw new InvalidDataException("Unsupported DDS pixel format.");
            int bytes = (int)bits / 8;
            int stride = width * bytes;
            uint pitch = U32(data, 20);
            if ((U32(data, 8) & 8) != 0 && pitch >= stride && 128L + (long)pitch * height <= data.Length)
                stride = (int)pitch;
            if (128L + (long)stride * height > data.Length) throw new InvalidDataException("Truncated DDS pixels.");
            Channel red = new Channel(U32(data, 92)), green = new Channel(U32(data, 96));
            Channel blue = new Channel(U32(data, 100)), opacity = new Channel(U32(data, 104));
            bool luminance = (U32(data, 80) & 0x20000) != 0;
            for (int y = 0; y < height; ++y)
            {
                int offset = 128 + y * stride;
                for (int x = 0; x < width; ++x, offset += bytes)
                {
                    uint value = 0;
                    for (int b = 0; b < bytes; ++b) value |= (uint)data[offset + b] << (8 * b);
                    byte r = red.Read(value, 255);
                    int pos = (y * width + x) * 4;
                    pixels[pos] = luminance ? r : blue.Read(value, 0);
                    pixels[pos + 1] = luminance ? r : green.Read(value, 0);
                    pixels[pos + 2] = r;
                    pixels[pos + 3] = ResolveAlpha(opacity.Read(value, 255), alpha);
                }
            }
        }
    }
}
