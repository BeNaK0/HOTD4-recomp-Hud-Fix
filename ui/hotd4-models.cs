using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Media3D;

namespace Hotd4Models
{
    public sealed class Entry
    {
        public string Name { get; internal set; }
        public string Bank { get; internal set; }
        public int Index { get; internal set; }
        public string Category { get; internal set; }
        public string CharacterName { get; internal set; }
        public string DisplayName { get { return CharacterName ?? Name; } }
        public string ListDetails
        {
            get { return (CharacterName == null ? "" : Name + "  ·  ") + Bank + "  #" + Index; }
        }
        public bool SupportsCharacterHd
        {
            get { return IsMain && (Name == "zp01a0_oh_james.lno" || Name == "zp02a0_oh_kate.lno" || Name == "zb01a0_iw_justc.lno"); }
        }
        public string Section { get { return IsMain ? "Main models" : "Other models"; } }
        internal bool IsMain;
        internal string Path;
        internal Catalog Catalog;
        internal int Start, Length, DataBase, ObjectChunk;
        internal short[] Parents;
    }

    public sealed partial class Catalog
    {
        public List<Entry> Entries { get; private set; }
        public int EmptyModels { get; private set; }
        public int OtherFormats { get; private set; }
        public List<string> BankErrors { get; private set; }
        public int TextureCount { get; private set; }
        private readonly Dictionary<string, List<TextureEntry>> textures =
            new Dictionary<string, List<TextureEntry>>(StringComparer.OrdinalIgnoreCase);

        public Catalog(string directory)
        {
            Entries = new List<Entry>();
            BankErrors = new List<string>();
            string[] paths = Directory.GetFiles(directory, "*.bnk", SearchOption.AllDirectories);
            Array.Sort(paths, StringComparer.OrdinalIgnoreCase);
            foreach (string path in paths)
            {
                try { ReadBank(path); }
                catch (IOException e) { BankErrors.Add(System.IO.Path.GetFileName(path) + ": " + e.Message); }
            }
            Entries.Sort(CompareEntries);
            MarkMainModels();
            Entries.Sort((a, b) => a.IsMain != b.IsMain ? b.IsMain.CompareTo(a.IsMain) : CompareEntries(a, b));
        }

        private static int CompareEntries(Entry a, Entry b)
        {
            int order = StringComparer.OrdinalIgnoreCase.Compare(a.Name, b.Name);
            if (order != 0) return order;
            order = StringComparer.OrdinalIgnoreCase.Compare(a.Bank, b.Bank);
            return order != 0 ? order : a.Index.CompareTo(b.Index);
        }

        // IZCA bank and Sega NN LNO layouts cross-checked against Argx2121/Sega_NN_tools.
        private void ReadBank(string path)
        {
            using (var reader = new BinaryReader(File.OpenRead(path), Encoding.ASCII))
            {
                long length = reader.BaseStream.Length;
                if (length < 16 || Tag(reader) != "IZCA") return;
                Seek(reader, 8, 4, length);
                long directory = reader.ReadUInt32() + 8L;
                Seek(reader, directory, 8, length);
                long table = reader.ReadUInt32();
                int count = reader.ReadInt32();
                if (count < 0) throw new IOException("Invalid bank directory.");
                Seek(reader, table, 4L * count, length);
                for (int index = 0; index < count; ++index)
                {
                    reader.BaseStream.Position = table + 4L * index;
                    long offset = reader.ReadUInt32();
                    Seek(reader, offset, 12, length);
                    string tag = Tag(reader);
                    if (tag != "HMDL" && tag != "VMDL" && tag != "HMOT" && tag != "VMOT" &&
                        tag != "ABRS" && tag != "HTEX" && tag != "HDDM") continue;
                    int size = reader.ReadInt32();
                    long start = offset + reader.ReadUInt32();
                    Seek(reader, start, size, length);
                    if (tag == "ABRS") ReadResources(reader, path, index, (int)start, size);
                    else if (tag == "HTEX" || tag == "HDDM") ReadTextures(reader, path, start, start + size);
                    else ReadEntry(reader, path, index, (int)start, size, tag == "HMDL" || tag == "VMDL");
                }
            }
        }

        private void ReadResources(BinaryReader reader, string path, int index, int start, int size)
        {
            // ABRS groups complete NN files alongside their other resources.
            byte[] group = reader.ReadBytes(size);
            for (int offset = 0; offset <= group.Length - 32; ++offset)
            {
                if (group[offset] == 'D' && group[offset + 1] == 'D' &&
                    group[offset + 2] == 'M' && group[offset + 3] == ' ')
                {
                    long next = ReadTextures(reader, path, start + offset, (long)start + size);
                    offset = (int)(next - start - 1);
                    continue;
                }
                if (group[offset] != 'N' || group[offset + 1] != 'L' || group[offset + 2] != 'I' ||
                    group[offset + 3] != 'F' || BitConverter.ToInt32(group, offset + 4) != 24)
                    continue;
                int end = ReadEntry(reader, path, index, start + offset, size - offset, false);
                offset = end - start - 1;
            }
        }

        private long ReadTextures(BinaryReader reader, string path, long start, long limit)
        {
            Seek(reader, start, 8, limit);
            if (Tag(reader) != "DDM ") return start + 1;
            long names = start + 8 + reader.ReadUInt32();
            if (names > limit - 16) return start + 1;
            Seek(reader, names, 16, limit);
            if (Tag(reader) != "DSFN") return start + 1;
            int namesSize = reader.ReadInt32();
            if (namesSize < 8 || namesSize > 1048576) throw new IOException("Invalid DDS name table.");
            reader.ReadUInt16();
            int count = reader.ReadUInt16();
            Seek(reader, names + 16, namesSize - 8, limit);
            byte[] nameTable = reader.ReadBytes(namesSize - 8);
            long chunk = names + 8 + namesSize;
            int nameIndex = 0;
            for (int i = 0; i < count; ++i)
            {
                int end = Array.IndexOf(nameTable, (byte)0, nameIndex);
                if (end < 0) throw new IOException("Truncated DDS name table.");
                string name = NormalizeTextureName(Encoding.ASCII.GetString(nameTable, nameIndex, end - nameIndex));
                nameIndex = end + 1;
                Seek(reader, chunk, 16, limit);
                if (Tag(reader) != "DSCK") return chunk;
                int blockSize = reader.ReadInt32(), ddsSize = reader.ReadInt32();
                if (blockSize < 8 || ddsSize < 0 || ddsSize > blockSize - 8)
                    throw new IOException("Invalid DDS data block.");
                Seek(reader, chunk + 16, ddsSize, limit);
                if (ddsSize >= 128 && name.Length != 0 && Tag(reader) == "DDS ")
                {
                    string leaf = TextureLeaf(name);
                    List<TextureEntry> matches;
                    if (!textures.TryGetValue(leaf, out matches))
                        textures.Add(leaf, matches = new List<TextureEntry>());
                    matches.Add(new TextureEntry { Path = path, Name = name, Offset = chunk + 16, Length = ddsSize });
                    ++TextureCount;
                }
                chunk += 8L + blockSize;
            }
            return chunk;
        }

        private static string NormalizeTextureName(string name)
        {
            return name.Replace('\\', '/').TrimStart('.', '/');
        }

        private static string TextureLeaf(string name) { return name.Substring(name.LastIndexOf('/') + 1); }

        internal TextureEntry FindTexture(Entry model, string reference)
        {
            string name = NormalizeTextureName(reference);
            List<TextureEntry> matches;
            if (!textures.TryGetValue(TextureLeaf(name), out matches)) return null;
            TextureEntry best = null;
            int bestScore = -1;
            bool mild = model.Bank.StartsWith("MILD_", StringComparison.OrdinalIgnoreCase);
            foreach (TextureEntry texture in matches)
            {
                int score = 0;
                if (String.Equals(texture.Path, model.Path, StringComparison.OrdinalIgnoreCase)) score += 16;
                if (name.IndexOf('/') >= 0 && String.Equals(texture.Name, name, StringComparison.OrdinalIgnoreCase)) score += 8;
                if (texture.Name.IndexOf("/BANK_" + model.Bank + "/", StringComparison.OrdinalIgnoreCase) >= 0) score += 4;
                if (System.IO.Path.GetFileName(texture.Path).StartsWith("MILD_", StringComparison.OrdinalIgnoreCase) == mild) ++score;
                if (score > bestScore) { best = texture; bestScore = score; }
            }
            return best;
        }

        private int ReadEntry(BinaryReader reader, string path, int index, int start, int size, bool modelRecord)
        {
            long limit = (long)start + size;
            Seek(reader, start, 8, limit);
            if (Tag(reader) != "NLIF") { ++OtherFormats; return (int)limit; }
            long dataBase = start + 8L + reader.ReadUInt32();
            long obj = -1;
            long motion = -1;
            string bank = System.IO.Path.GetFileNameWithoutExtension(path);
            string name = bank + " #" + (index + 1);
            for (long chunk = dataBase; chunk + 8 <= limit;)
            {
                reader.BaseStream.Position = chunk;
                string tag = Tag(reader);
                int chunkSize = reader.ReadInt32();
                Seek(reader, chunk + 8, chunkSize, limit);
                if (tag == "NLOB") obj = chunk;
                if (tag == "NLMO") motion = chunk;
                if (tag == "NFN0" && chunkSize >= 8)
                {
                    reader.BaseStream.Position = chunk + 16;
                    byte[] chars = reader.ReadBytes(Math.Min(chunkSize - 8, 1024));
                    int zero = Array.IndexOf(chars, (byte)0);
                    string stored = Encoding.ASCII.GetString(chars, 0, zero < 0 ? chars.Length : zero);
                    int slash = Math.Max(stored.LastIndexOf('/'), stored.LastIndexOf('\\'));
                    if (stored.Length > slash + 1) name = stored.Substring(slash + 1);
                }
                if (tag == "NEND") { limit = chunk + 8L + chunkSize; break; }
                chunk += 8L + chunkSize;
            }
            if (motion >= 0) ReadMotion(reader, path, bank, name, index + 1, start, limit, dataBase, motion);
            if (obj < 0)
            {
                if (modelRecord) ++EmptyModels;
                return (int)limit;
            }
            Seek(reader, obj + 8, 4, limit);
            long info = dataBase + reader.ReadUInt32();
            Seek(reader, info + 56, 4, limit);
            if (reader.ReadUInt32() == 0) { ++EmptyModels; return (int)limit; }
            short[] parents = ReadParents(reader, info, dataBase, limit);
            Entries.Add(new Entry { Name = name, Bank = bank, Index = index + 1, Category = ModelCategory(bank, name),
                Path = path, Catalog = this, Parents = parents, Start = start, Length = (int)(limit - start),
                DataBase = (int)(dataBase - start), ObjectChunk = (int)(obj - start) });
            return (int)limit;
        }

        private static string Tag(BinaryReader reader) { return Encoding.ASCII.GetString(reader.ReadBytes(4)); }

        private static void Seek(BinaryReader reader, long offset, long bytes, long limit)
        {
            if (offset < 0 || bytes < 0 || offset > limit - bytes)
                throw new IOException("A chunk points outside its parent.");
            reader.BaseStream.Position = offset;
        }
    }

    public sealed partial class Model
    {
        public Model3DGroup Geometry { get; private set; }
        public int MeshCount { get; private set; }
        public int Triangles { get; private set; }
        public int TexturedMeshes { get; private set; }
        public int MissingTextures { get; private set; }
        public int HdTextures { get; private set; }
        private readonly byte[] bytes;
        private readonly int dataBase;

        private sealed class Vertices
        {
            internal Point3DCollection Positions = new Point3DCollection();
            internal Vector3DCollection Normals;
            internal PointCollection UV;
            internal int Palette, Weights, Indices, WeightSize, IndexSize;
        }

        private sealed class SurfaceInfo
        {
            internal Color Color = Color.FromRgb(177, 189, 198);
            internal string Texture;
            internal float X, Y, Width = 1, Height = 1;
        }

        public Model(Entry entry) : this(entry, true) { }

        public Model(Entry entry, bool decodeTextures) : this(entry, decodeTextures, null) { }

        public Model(Entry entry, bool decodeTextures, string hdPack) : this(entry, decodeTextures, hdPack, false) { }

        public Model(Entry entry, bool decodeTextures, string hdPack, bool enhanceCharacters)
        {
            bool enhance = enhanceCharacters && entry.SupportsCharacterHd;
            using (var reader = new BinaryReader(File.OpenRead(entry.Path)))
            {
                reader.BaseStream.Position = entry.Start;
                bytes = reader.ReadBytes(entry.Length);
            }
            dataBase = entry.DataBase;
            sourceEntry = entry;
            int info = Pointer(entry.ObjectChunk + 8);
            if (entry.Parents.Length != 0) boneTable = Pointer(info + 48);
            int materialCount = Count(info + 16, 131072);
            int materialTable = Pointer(info + 20);
            int vertexCount = Count(info + 24, 131072);
            int vertexTable = Pointer(info + 28);
            int faceCount = Count(info + 32, 131072);
            int faceTable = Pointer(info + 36);
            int setCount = Count(info + 56, 128);
            int sets = Pointer(info + 60);
            Geometry = new Model3DGroup();
            var vertices = new Dictionary<int, Vertices>();
            var materials = new Dictionary<int, SurfaceInfo>();
            var brushes = new Dictionary<TextureEntry, Material[]>();
            var hdTextures = new HashSet<TextureEntry>();
            string[] textureNames = TextureNames(entry.ObjectChunk);
            for (int set = 0; set < setCount; ++set)
            {
                int setInfo = sets + set * 20;
                uint renderFlags = U32(setInfo) & 7;
                TextureAlpha alpha = (renderFlags & 4) != 0 ? TextureAlpha.Cutout :
                                     (renderFlags & 2) != 0 ? TextureAlpha.Blend : TextureAlpha.Opaque;
                int count = Count(setInfo + 4, 131072);
                int meshTable = Pointer(setInfo + 8);
                for (int meshIndex = 0; meshIndex < count; ++meshIndex)
                {
                    int mesh = meshTable + meshIndex * 48;
                    int material = Count(mesh + 24, materialCount - 1);
                    int v = Count(mesh + 28, vertexCount - 1);
                    int f = Count(mesh + 32, faceCount - 1);
                    Vertices vertex;
                    if (!vertices.TryGetValue(v, out vertex))
                    {
                        vertex = GetVertices(vertexTable + 8 * v);
                        vertices.Add(v, vertex);
                    }
                    Int32Collection triangles = GetTriangles(faceTable + 8 * f, vertex.Positions.Count);
                    if (triangles.Count == 0) continue;
                    var part = new MeshGeometry3D { Positions = vertex.Positions, TriangleIndices = triangles };
                    if (vertex.Normals != null) part.Normals = vertex.Normals;
                    SurfaceInfo appearance;
                    if (!materials.TryGetValue(material, out appearance))
                    {
                        appearance = ReadMaterial(materialTable + 8 * material, textureNames);
                        materials.Add(material, appearance);
                    }
                    Material surface = null;
                    if (appearance.Texture != null && vertex.UV != null)
                    {
                        TextureEntry texture = entry.Catalog.FindTexture(entry, appearance.Texture);
                        if (texture != null)
                        {
                            if (!decodeTextures) ++TexturedMeshes;
                            else
                            {
                                surface = TexturedSurface(texture, alpha, brushes, hdPack, hdTextures, enhance);
                                if (surface != null)
                                {
                                    ++TexturedMeshes;
                                    part.TextureCoordinates = TextureCoordinates(vertex.UV, appearance);
                                }
                            }
                        }
                        if (texture == null || (decodeTextures && surface == null)) ++MissingTextures;
                    }
                    part.Freeze();
                    if (surface == null) surface = new DiffuseMaterial(new SolidColorBrush(appearance.Color));
                    Geometry.Children.Add(new GeometryModel3D(part, surface) { BackMaterial = surface });
                    skinParts.Add(new SkinPart(vertex, (int)U32(mesh + 20), (int)U32(mesh + 16)));
                    ++MeshCount;
                    Triangles += triangles.Count / 3;
                }
            }
            HdTextures = hdTextures.Count;
            Geometry.Freeze();
        }

        private Vertices GetVertices(int table)
        {
            var vertices = new Vertices();
            if (U32(table) == 4) return vertices;
            int info = Pointer(table + 4);
            int count = Count(info + 4, 1000000);
            int streams = Count(info + 8, 128);
            int offset = Pointer(info + 12);
            vertices.Palette = info;
            for (int stream = 0; stream < streams; ++stream)
            {
                int record = offset + 20 * stream;
                uint format = U32(record) & 0x7fffffffu;
                if (format == 2 || format == 4)
                {
                    int sampleSize = Count(record + 12, 16);
                    int samples = Pointer(record + 16);
                    Require(samples, (long)sampleSize * count);
                    if (format == 2) { vertices.Weights = samples; vertices.WeightSize = sampleSize; }
                    else { vertices.Indices = samples; vertices.IndexSize = sampleSize; }
                }
                if (format != 1 && format != 8 && format != 256) continue;
                int start = Pointer(record + 16);
                int stride = format == 256 ? 8 : 12;
                Require(start, (long)stride * count);
                if (format == 1)
                {
                    var points = new Point3DCollection(count);
                    for (int i = 0; i < count; ++i)
                    {
                        int v = start + stride * i;
                        points.Add(new Point3D(Float(v), Float(v + 4), Float(v + 8)));
                    }
                    points.Freeze();
                    vertices.Positions = points;
                }
                else if (format == 8)
                {
                    var normals = new Vector3DCollection(count);
                    for (int i = 0; i < count; ++i)
                    {
                        int v = start + stride * i;
                        normals.Add(new Vector3D(Float(v), Float(v + 4), Float(v + 8)));
                    }
                    normals.Freeze();
                    vertices.Normals = normals;
                }
                else if (vertices.UV == null)
                {
                    var uv = new PointCollection(count);
                    for (int i = 0; i < count; ++i)
                    {
                        int v = start + stride * i;
                        uv.Add(new Point(Float(v), Float(v + 4)));
                    }
                    uv.Freeze();
                    vertices.UV = uv;
                }
            }
            return vertices;
        }

        private Int32Collection GetTriangles(int table, int vertices)
        {
            var triangles = new Int32Collection();
            if (vertices == 0) return triangles;
            int info = Pointer(table + 4);
            int count = Count(info + 20, bytes.Length) / 2;
            int start = Pointer(info + 24);
            Require(start, count * 2L);
            int a = -1, b = -1, strip = 0;
            for (int i = 0; i < count; ++i)
            {
                int c = BitConverter.ToUInt16(bytes, start + 2 * i);
                if (c == 65535) { a = b = -1; strip = 0; continue; }
                if (c >= vertices) throw new IOException("Triangle index exceeds the vertex count.");
                if (strip >= 2 && a != b && b != c && a != c)
                {
                    triangles.Add((strip & 1) == 0 ? a : b);
                    triangles.Add((strip & 1) == 0 ? b : a);
                    triangles.Add(c);
                }
                a = b; b = c; ++strip;
            }
            triangles.Freeze();
            return triangles;
        }

        private string[] TextureNames(int objectChunk)
        {
            for (int chunk = dataBase; chunk < objectChunk; chunk += 8 + Count(chunk + 4, bytes.Length - chunk - 8))
            {
                if (U32(chunk) != 0x4c544c4e) continue;  // NLTL
                int info = checked(chunk + Count(chunk + 8, bytes.Length - chunk));
                int count = Count(info, 131072), table = Pointer(info + 4);
                var names = new string[count];
                for (int i = 0; i < count; ++i)
                {
                    int start = Pointer(table + i * 20 + 4);
                    int end = Array.IndexOf(bytes, (byte)0, start, Math.Min(1024, bytes.Length - start));
                    if (end >= 0) names[i] = Encoding.ASCII.GetString(bytes, start, end - start);
                }
                return names;
            }
            return new string[0];
        }

        private SurfaceInfo ReadMaterial(int table, string[] names)
        {
            int info = Pointer(table + 4);
            var material = new SurfaceInfo();
            if (U32(info + 8) != 0)
            {
                int diffuse = Pointer(info + 8) + 20;
                Require(diffuse, 16);
                material.Color = Color.FromArgb(255, ColorByte(Float(diffuse)),
                    ColorByte(Float(diffuse + 4)), ColorByte(Float(diffuse + 8)));
            }
            int count = Count(info + 20, 128);
            int start = Pointer(info + 24);
            for (int i = 0; i < count; ++i)
            {
                int tex = start + i * 64;
                uint flags = U32(tex);
                uint index = U32(tex + 4);
                // The diffuse layer's primary UV set is zero. Environment
                // maps use -1 and are left to the game's renderer.
                if ((flags & 0x02000002u) == 0 || index >= names.Length || U32(tex + 8) != 0)
                    continue;
                material.Texture = names[index];
                if ((flags & 0x40000000u) == 0)
                {
                    material.X = Float(tex + 16);
                    material.Y = Float(tex + 20);
                    if ((flags & 0x20000000u) != 0)
                    {
                        material.Width = Float(tex + 24);
                        material.Height = Float(tex + 28);
                    }
                }
                break;
            }
            return material;
        }

        private static byte ColorByte(float value)
        {
            return (byte)Math.Round(255 * Math.Max(0, Math.Min(1, value)));
        }

        private static PointCollection TextureCoordinates(PointCollection points, SurfaceInfo material)
        {
            if (material.X == 0 && material.Y == 0 && material.Width == 1 && material.Height == 1)
                return points;
            var uv = new PointCollection(points.Count);
            foreach (Point p in points)
                uv.Add(new Point(p.X * material.Width + material.X, p.Y * material.Height + material.Y));
            uv.Freeze();
            return uv;
        }

        private static Material TexturedSurface(TextureEntry texture, TextureAlpha alpha,
                                                 Dictionary<TextureEntry, Material[]> brushes,
                                                 string hdPack, HashSet<TextureEntry> hdTextures, bool enhance)
        {
            Material[] versions;
            if (!brushes.TryGetValue(texture, out versions))
                brushes.Add(texture, versions = new Material[3]);
            if (versions[(int)alpha] != null) return versions[(int)alpha];
            try
            {
                bool replaced;
                var brush = new ImageBrush(texture.Load(alpha, hdPack, enhance, out replaced)) {
                    ViewportUnits = BrushMappingMode.Absolute, Viewport = new Rect(0, 0, 1, 1),
                    TileMode = TileMode.Tile, Stretch = Stretch.Fill
                };
                var surface = new DiffuseMaterial(brush);
                surface.Freeze();
                if (replaced) hdTextures.Add(texture);
                return versions[(int)alpha] = surface;
            }
            catch (InvalidDataException) { return null; }
            catch (IOException) { return null; }
        }

        private uint U32(int offset) { Require(offset, 4); return BitConverter.ToUInt32(bytes, offset); }
        private int Pointer(int offset)
        {
            long address = dataBase + (long)U32(offset);
            if (address < 0 || address > bytes.Length) throw new IOException("Invalid model pointer.");
            return (int)address;
        }
        private int Count(int offset, int maximum)
        {
            uint value = U32(offset);
            if (maximum < 0 || value > maximum) throw new IOException("Invalid model table count or index.");
            return (int)value;
        }
        private float Float(int offset)
        {
            float value = BitConverter.ToSingle(bytes, offset);
            if (float.IsNaN(value) || float.IsInfinity(value)) throw new IOException("Invalid vertex.");
            return value;
        }
        private void Require(int offset, long count)
        {
            if (offset < 0 || count < 0 || offset > bytes.Length - count)
                throw new IOException("A model table points outside the archive entry.");
        }
    }
}
