using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Windows.Media.Media3D;

namespace Hotd4Models
{
    public sealed class Motion
    {
        public string Name { get; internal set; }
        public string Bank { get; internal set; }
        public string Label { get; internal set; }
        public double Start { get; internal set; }
        public double End { get; internal set; }
        public double Rate { get; internal set; }
        public int PreviewOrder { get { return Order == 4 ? -1 : Order; } }
        internal string Path;
        internal long Offset, Limit, Base;
        internal int Count, MaxNode, Order;
        internal bool Unnamed;
    }

    public sealed partial class Catalog
    {
        private readonly List<Motion> motions = new List<Motion>();
        public int MotionCount { get { return motions.Count; } }
        private static readonly Regex actor = new Regex(@"^z[bhlmnpst]\d\d[a-z]", RegexOptions.IgnoreCase);
        private static readonly Regex weapons = new Regex(@"(?:^|_)(?:smg|machinegun|grenade|granade|weapon)(?:_|\.|$)",
            RegexOptions.IgnoreCase);

        private static string CleanBank(string bank)
        {
            return Regex.Replace(Regex.Replace(bank.ToLowerInvariant(), @"^(?:mild_|aab_)", ""), @"(?:_vr|_morph)$", "");
        }

        private static string ActorKey(string bank, string name)
        {
            Match match = actor.Match(CleanBank(bank));
            if (!match.Success) match = actor.Match(name);
            return match.Success ? match.Value.ToLowerInvariant() : "";
        }

        private static string ModelCategory(string bank, string name)
        {
            string key = ActorKey(bank, name);
            string lower = name.ToLowerInvariant();
            if (weapons.IsMatch(name) || lower.Contains("_smg_")) return "Weapons";
            if (key.StartsWith("zp")) return "Players";
            if (key.StartsWith("zb")) return "Bosses";
            if (key.Length != 0) return "Enemies";
            if (lower.StartsWith("item_") || lower.Contains("_o_") || lower == "life.lno") return "Props & Items";
            string context = CleanBank(bank);
            if (lower.StartsWith("hod4_") || context.Contains("logo") || context.Contains("ranking") ||
                context.Contains("title") || context.Contains("tutorial") || context == "primitive") return "Effects & UI";
            if (context.StartsWith("stage") || Regex.IsMatch(lower, @"^st\d")) return "Environments";
            return "Other";
        }

        // Prefer complete character meshes in the primary actor banks.
        private static readonly Regex actorPart = new Regex(
            @"_(?:bone|arms?|hands?|head|hair|morph)(?:_|\.)|^\w{4}h\d_", RegexOptions.IgnoreCase);

        private static readonly Dictionary<string, string> characterNames =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
                { "zp01a0_oh_james.lno", "James Taylor" },
                { "zp02a0_oh_kate.lno", "Kate Green" },
                { "zp03a0_oh_gold.lno", "Goldman" },
                { "zb01a0_iw_justc.lno", "Justice" },
                { "zb02a0_iw_lover.lno", "The Lovers" },
                { "zb03a0_ur_empress.lno", "The Empress" },
                { "zb04a0_iw_temper.lno", "Temperance" },
                { "zb05a0_iw_star.lno", "The Star" },
                { "zb06a0_tr_world.lno", "The World" }
            };

        private void MarkMainModels()
        {
            var primary = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
            foreach (Entry entry in Entries)
            {
                if (entry.Category != "Enemies" && entry.Category != "Bosses" && entry.Category != "Players")
                    continue;
                string key = ActorKey(entry.Bank, entry.Name);
                if (key.Length == 0 || !String.Equals(key, entry.Bank, StringComparison.OrdinalIgnoreCase) ||
                    !entry.Name.StartsWith(key.Substring(0, 4), StringComparison.OrdinalIgnoreCase) ||
                    !entry.Name.EndsWith(".lno", StringComparison.OrdinalIgnoreCase) ||
                    actorPart.IsMatch(entry.Name) || entry.Parents.Length < 8) continue;
                Entry previous;
                if (!primary.TryGetValue(key.Substring(0, 4), out previous) ||
                    entry.Parents.Length > previous.Parents.Length)
                    primary[key.Substring(0, 4)] = entry;
            }
            foreach (Entry entry in primary.Values)
            {
                entry.IsMain = true;
                string name;
                if (characterNames.TryGetValue(entry.Name, out name)) entry.CharacterName = name;
            }
        }

        private static string MotionKind(string name, out int order)
        {
            string lower = name.ToLowerInvariant();
            if (lower.Contains("_walk")) { order = 0; return "Walk"; }
            if (lower.Contains("_run")) { order = 1; return "Run"; }
            if (lower.Contains("_atk") || lower.Contains("_attack") || lower.Contains("_hold")) { order = 2; return "Attack"; }
            if (lower.Contains("_fall") || lower.Contains("_dmg_h") || lower.Contains("_dmg_granade") ||
                lower.Contains("gameover") || lower.Contains("_death")) { order = 3; return "Fall / heavy hit"; }
            if (lower.Contains("_wait") || lower.Contains("_idle")) { order = 4; return "Idle"; }
            if (lower.Contains("reload")) { order = 5; return "Reload"; }
            if (lower.Contains("_dmg") || lower.Contains("_yara")) { order = 6; return "Hit reaction"; }
            order = 7;
            return "";
        }

        private static short[] ReadParents(BinaryReader reader, long info, long dataBase, long limit)
        {
            Seek(reader, info + 40, 12, limit);
            int count = reader.ReadInt32();
            reader.ReadInt32();
            long table = dataBase + reader.ReadUInt32();
            if (count <= 0 || count > 32768 || table + 144L * count > limit) return new short[0];
            var result = new short[count];
            for (int i = 0; i < count; ++i)
            {
                reader.BaseStream.Position = table + i * 144L + 6;
                result[i] = reader.ReadInt16();
            }
            return result;
        }

        private void ReadMotion(BinaryReader reader, string path, string bank, string name, int index,
                                long start, long limit, long dataBase, long chunk)
        {
            Seek(reader, chunk + 8, 4, limit);
            long info = dataBase + reader.ReadUInt32();
            Seek(reader, info, 24, limit);
            if ((reader.ReadUInt32() & 31) != 1) return;
            float first = reader.ReadSingle(), last = reader.ReadSingle();
            int count = reader.ReadInt32();
            long table = dataBase + reader.ReadUInt32();
            float fps = reader.ReadSingle();
            if (!(last > first) || !(fps > 0 && fps <= 240) || count <= 0 || count > 65536) return;
            Seek(reader, table, count * 40L, limit);
            int max = -1, supported = 0;
            for (int i = 0; i < count; ++i)
            {
                reader.BaseStream.Position = table + 40L * i;
                uint type = reader.ReadUInt32();
                reader.ReadUInt32();
                int node = reader.ReadInt32();
                if (node < 0) continue;
                if (MotionTrack.Components(type) != 0) ++supported;
                max = Math.Max(max, node);
            }
            if (supported == 0 || max < 0) return;
            bool unnamed = name == bank + " #" + index;
            if (unnamed) name = bank + " | Clip " + index;
            int order;
            string kind = MotionKind(name, out order);
            motions.Add(new Motion { Name = name, Bank = bank, Label = kind.Length == 0 ? name : kind + "  |  " + name,
                Path = path, Offset = table, Limit = limit, Base = dataBase, Count = count, MaxNode = max, Order = order,
                Unnamed = unnamed, Start = first, End = last, Rate = fps });
        }

        private static bool SameHierarchy(short[] a, short[] b, int count)
        {
            if (a.Length < count || b.Length < count) return false;
            for (int i = 0; i < count; ++i) if (a[i] != b[i]) return false;
            return true;
        }

        private static string Segment(string name)
        {
            string lower = name.ToLowerInvariant();
            if (lower.Contains("l_hand")) return "left hand";
            if (lower.Contains("r_hand")) return "right hand";
            if (lower.Contains("_arms")) return "arms";
            if (weapons.IsMatch(name)) return "weapon";
            return "";
        }

        private static string Stem(string name)
        {
            int extension = name.LastIndexOf('.');
            return extension >= 0 ? name.Substring(0, extension) : name;
        }

        public List<Motion> Animations(Entry model)
        {
            var result = new List<Motion>();
            if (model == null || model.Parents.Length == 0) return result;
            string modelBank = CleanBank(model.Bank);
            string modelName = Stem(model.Name);
            string key = ActorKey(model.Bank, model.Name);
            string part = Segment(model.Name);
            Entry sharedRig = Entries.Find(e => e.Bank == "zn01a" && e.Name == "zn01a_bone.lno");
            bool commonRig = sharedRig != null && SameHierarchy(model.Parents, sharedRig.Parents, 39);

            // Identify an actor bank's principal body rig. This keeps boss
            // attachments with their own node layout off the full-body clips.
            Entry principal = null;
            if (key.Length != 0 && part.Length == 0)
            {
                foreach (Entry entry in Entries)
                {
                    if (CleanBank(entry.Bank) != key || Segment(entry.Name).Length != 0 ||
                        entry.Name.IndexOf("morph", StringComparison.OrdinalIgnoreCase) >= 0) continue;
                    if (principal == null || entry.Parents.Length > principal.Parents.Length) principal = entry;
                }
            }
            var matches = new Dictionary<string, Motion>(StringComparer.OrdinalIgnoreCase);
            foreach (Motion clip in motions)
            {
                int required = clip.MaxNode + 1;
                if (required > model.Parents.Length) continue;
                string bank = CleanBank(clip.Bank);
                string name = Stem(clip.Name);
                bool same = String.Equals(name, modelName, StringComparison.OrdinalIgnoreCase);
                bool actorRig = required >= 12 && ((commonRig && required <= 39) ||
                                (principal != null && SameHierarchy(model.Parents, principal.Parents, required)));
                bool actorClip = key.Length != 0 &&
                    (name.StartsWith(key, StringComparison.OrdinalIgnoreCase) || (bank == key && clip.Unnamed));
                bool shared = commonRig && key.Length != 0 && key.StartsWith("zn") && required <= 39 &&
                    (bank == "znall" || bank == "zn00a") && !clip.Unnamed;
                if (key.Length != 0 && commonRig && required <= 39 &&
                    (bank == key.Substring(0, 2) + "all") && !clip.Unnamed) shared = true;
                bool pairedPart = part.Length != 0 && part == Segment(name) && actorClip;
                bool weapon = model.Category == "Weapons" && modelName.IndexOf("smg", StringComparison.OrdinalIgnoreCase) >= 0 &&
                              (name.IndexOf("machinegun", StringComparison.OrdinalIgnoreCase) >= 0 ||
                               name.EndsWith("_smg", StringComparison.OrdinalIgnoreCase));
                bool grenade = model.Category == "Weapons" && required == 1 &&
                    modelName.Equals("item_grenade", StringComparison.OrdinalIgnoreCase) &&
                    (name.EndsWith("_grenade", StringComparison.OrdinalIgnoreCase) ||
                     name.EndsWith("_granade", StringComparison.OrdinalIgnoreCase));
                if (!same && !pairedPart && !weapon && !grenade && !(part.Length == 0 && Segment(name) == "" &&
                    (shared || (actorClip && actorRig)))) continue;

                Motion previous;
                if (!matches.TryGetValue(clip.Name, out previous) || clip.Bank == model.Bank ||
                    (CleanBank(previous.Bank) != modelBank && bank == modelBank))
                    matches[clip.Name] = clip;
            }
            result.AddRange(matches.Values);
            result.Sort((a, b) => a.Order != b.Order ? a.Order.CompareTo(b.Order) :
                StringComparer.OrdinalIgnoreCase.Compare(a.Name, b.Name));
            return result;
        }
    }

    internal sealed class MotionTrack
    {
        internal int Node, Channel;
        internal bool Constant;
        internal float[] Frames, Values;

        internal static uint Components(uint type)
        {
            return type & 0x0013bf00;  // XYZ translation, rotation and scale, and visibility
        }

        internal double Sample(double frame)
        {
            if (frame <= Frames[0]) return Values[0];
            int end = Frames.Length - 1;
            if (frame >= Frames[end]) return Values[end];
            int first = 0;
            while (end - first > 1)
            {
                int mid = (first + end) / 2;
                if (frame >= Frames[mid]) first = mid; else end = mid;
            }
            if (Constant || Frames[end] <= Frames[first]) return Values[first];
            double span = Values[end] - Values[first];
            if (Channel >= 3 && Channel <= 5) span = Math.IEEERemainder(span, 65536);
            return Values[first] + span * ((frame - Frames[first]) / (Frames[end] - Frames[first]));
        }

        internal static List<MotionTrack> Load(Motion motion)
        {
            var tracks = new List<MotionTrack>();
            using (var reader = new BinaryReader(File.OpenRead(motion.Path)))
            {
                for (int i = 0; i < motion.Count; ++i)
                {
                    reader.BaseStream.Position = motion.Offset + i * 40L;
                    uint type = reader.ReadUInt32();
                    uint interp = reader.ReadUInt32();
                    int node = reader.ReadInt32();
                    reader.ReadSingle(); reader.ReadSingle();
                    float keyStart = reader.ReadSingle(), keyEnd = reader.ReadSingle();
                    int keys = reader.ReadInt32(), stride = reader.ReadInt32();
                    long offset = motion.Base + reader.ReadUInt32();
                    uint components = Components(type);
                    if (node < 0 || components == 0 || keys <= 0 || keys > 100000 || stride <= 0 ||
                        offset + keys * (long)stride > motion.Limit) continue;
                    bool shortValue = (type & 16) != 0;
                    int frameSize = (type & 1) != 0 ? 4 : (type & 2) != 0 ? 2 : 0;
                    var channels = new List<MotionTrack>();
                    for (int bit = 8; bit <= 20; ++bit)
                        if ((components & (1u << bit)) != 0)
                            channels.Add(new MotionTrack { Node = node, Channel = bit - 8, Constant = (interp & 4) != 0 || bit == 20,
                                Frames = new float[keys], Values = new float[keys] });
                    if (frameSize + channels.Count * (shortValue ? 2 : 4) > stride) continue;
                    for (int k = 0; k < keys; ++k)
                    {
                        reader.BaseStream.Position = offset + k * (long)stride;
                        float time = frameSize == 4 ? reader.ReadSingle() : frameSize == 2 ? reader.ReadInt16() :
                                     keyStart + (keyEnd - keyStart) * k / Math.Max(keys - 1, 1);
                        foreach (MotionTrack channel in channels)
                        {
                            float val = shortValue ? reader.ReadInt16() : (type & 8) != 0 ? reader.ReadInt32() : reader.ReadSingle();
                            if ((type & 4) != 0 && channel.Channel >= 3 && channel.Channel <= 5)
                                val *= 10430.37835f;
                            channel.Frames[k] = time;
                            channel.Values[k] = val;
                        }
                    }
                    tracks.AddRange(channels);
                }
            }
            return tracks;
        }
    }

    public sealed partial class Model
    {
        private readonly List<SkinPart> skinParts = new List<SkinPart>();
        private Entry sourceEntry;
        private int boneTable;

        private sealed class SkinPart
        {
            internal Vertices Vertex;
            internal int Group, Node;
            internal SkinPart(Vertices vertex, int group, int node) { Vertex = vertex; Group = group; Node = node; }
        }

        private static readonly Vector3D[] axes = { new Vector3D(1,0,0), new Vector3D(0,1,0), new Vector3D(0,0,1) };
        private static readonly int[][] rotations = { new[] {0,1,2}, new[] {0,2,1}, new[] {2,0,1} };

        public Animation Animate(Motion clip)
        {
            if (clip == null || boneTable == 0 || sourceEntry.Parents.Length <= clip.MaxNode)
                throw new InvalidDataException("The clip does not match this model's skeleton.");
            return new Animation(this, clip);
        }

        public sealed class Animation
        {
            public Model3DGroup Geometry { get; private set; }
            public Motion Clip { get; private set; }

            private struct Joint
            {
                internal Matrix3D InverseBind;
                internal short Parent;
                internal int Order;
                internal double[] Rest;
            }

            private struct Weight
            {
                internal int Bone;
                internal double Amount;
            }

            private sealed class Part
            {
                internal GeometryModel3D Visual;
                internal MeshGeometry3D Mesh, Original;
                internal Material Material;
                internal Weight[][] Weights;
                internal int VisibilityNode;
                internal int RigidBone;
            }

            private readonly List<MotionTrack> tracks;
            private readonly Joint[] joints;
            private readonly Part[] parts;
            private readonly Matrix3D[] world, skin;
            private readonly double[][] pose;

            internal Animation(Model model, Motion clip)
            {
                Clip = clip;
                tracks = MotionTrack.Load(clip);
                if (tracks.Count == 0) throw new InvalidDataException("This clip has no supported joint tracks.");
                int count = model.sourceEntry.Parents.Length;
                joints = new Joint[count];
                pose = new double[count][];
                world = new Matrix3D[count];
                skin = new Matrix3D[count];
                var groups = new Dictionary<int, int>();
                for (int i = 0; i < count; ++i)
                {
                    int offset = model.boneTable + i * 144;
                    uint flags = model.U32(offset);
                    short group = BitConverter.ToInt16(model.bytes, offset + 4);
                    short parent = model.sourceEntry.Parents[i];
                    if (parent >= i) throw new IOException("Unsupported joint hierarchy.");
                    if (group >= 0 && !groups.ContainsKey(group)) groups.Add(group, i);
                    double[] values = new double[13];
                    for (int j = 0; j < 3; ++j)
                    {
                        values[j] = model.Float(offset + 12 + j * 4);
                        values[3 + j] = (int)model.U32(offset + 24 + j * 4);
                        values[7 + j] = model.Float(offset + 36 + j * 4);
                    }
                    int r = (int)(flags >> 8) & 15;
                    joints[i] = new Joint { Parent = parent, Order = r == 1 ? 1 : r == 4 ? 2 : 0,
                        InverseBind = ReadMatrix(model, offset + 48), Rest = values };
                    pose[i] = new double[13];
                }
                Geometry = new Model3DGroup();
                parts = new Part[model.skinParts.Count];
                var paletteWeights = new Dictionary<Vertices, Weight[][]>();
                for (int n = 0; n < parts.Length; ++n)
                {
                    var original = (GeometryModel3D)model.Geometry.Children[n];
                    var mesh = (MeshGeometry3D)original.Geometry;
                    var editable = new MeshGeometry3D { Positions = mesh.Positions, Normals = mesh.Normals,
                        TextureCoordinates = mesh.TextureCoordinates, TriangleIndices = mesh.TriangleIndices };
                    var visible = new GeometryModel3D(editable, original.Material) { BackMaterial = original.BackMaterial };
                    SkinPart source = model.skinParts[n];
                    int rigid;
                    if (!groups.TryGetValue(source.Group, out rigid)) rigid = source.Node >= 0 && source.Node < count ? source.Node : 0;
                    Weight[][] weights;
                    if (!paletteWeights.TryGetValue(source.Vertex, out weights))
                    {
                        weights = ReadWeights(model, source.Vertex, groups);
                        paletteWeights.Add(source.Vertex, weights);
                    }
                    parts[n] = new Part { Visual = visible, Mesh = editable, Original = mesh, Material = original.Material,
                        Weights = weights, VisibilityNode = source.Node, RigidBone = rigid };
                    Geometry.Children.Add(visible);
                }
                SetFrame(clip.Start);
            }

            private static Matrix3D ReadMatrix(Model model, int start)
            {
                var values = new double[16];
                for (int i = 0; i < values.Length; ++i) values[i] = model.Float(start + i * 4);
                return new Matrix3D(values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7],
                                    values[8], values[9], values[10], values[11], values[12], values[13], values[14], values[15]);
            }

            private static Weight[][] ReadWeights(Model model, Vertices vertex, Dictionary<int, int> groups)
            {
                int size = model.Count(vertex.Palette + 24, 65535);
                if (size == 0) return null;
                int table = model.Pointer(vertex.Palette + 28);
                model.Require(table, size * 2L);
                var palette = new int[size];
                for (int i = 0; i < size; ++i)
                    if (!groups.TryGetValue(BitConverter.ToUInt16(model.bytes, table + i * 2), out palette[i])) palette[i] = -1;
                var vertices = new Weight[vertex.Positions.Count][];
                for (int i = 0; i < vertices.Length; ++i)
                {
                    var weights = new List<Weight>(4);
                    int count = vertex.WeightSize + 1;
                    double used = 0, total = 0;
                    for (int j = 0; j < count; ++j)
                    {
                        double weight = j == count - 1 ? Math.Max(0, 1 - used) :
                            model.bytes[vertex.Weights + i * vertex.WeightSize + j] / 255.0;
                        used += weight;
                        int slot = vertex.IndexSize == 0 ? j : j < vertex.IndexSize ?
                            model.bytes[vertex.Indices + i * vertex.IndexSize + j] : -1;
                        if (weight > 0 && slot >= 0 && slot < size && palette[slot] >= 0)
                        {
                            weights.Add(new Weight { Bone = palette[slot], Amount = weight });
                            total += weight;
                        }
                    }
                    vertices[i] = weights.ToArray();
                    if (total > 0 && total != 1)
                        for (int j = 0; j < vertices[i].Length; ++j) vertices[i][j].Amount /= total;
                }
                return vertices;
            }

            public void SetFrame(double frame)
            {
                for (int i = 0; i < joints.Length; ++i) Array.Copy(joints[i].Rest, pose[i], 13);
                foreach (MotionTrack track in tracks)
                    if (track.Node < pose.Length) pose[track.Node][track.Channel] = track.Sample(frame);
                for (int i = 0; i < joints.Length; ++i)
                {
                    Joint joint = joints[i];
                    double[] p = pose[i];
                    Matrix3D local = Matrix3D.Identity;
                    local.Scale(new Vector3D(p[7], p[8], p[9]));
                    foreach (int axis in rotations[joint.Order])
                        if (p[axis + 3] != 0) local.Rotate(new Quaternion(axes[axis], p[axis + 3] * (360.0 / 65536)));
                    local.Translate(new Vector3D(p[0], p[1], p[2]));
                    world[i] = joint.Parent >= 0 ? local * world[joint.Parent] : local;
                    skin[i] = joint.InverseBind * world[i];
                }
                foreach (Part part in parts)
                {
                    bool hidden = part.VisibilityNode >= 0 && part.VisibilityNode < pose.Length && pose[part.VisibilityNode][12] != 0;
                    part.Visual.Material = part.Visual.BackMaterial = hidden ? null : part.Material;
                    if (!hidden) Deform(part);
                }
            }

            private void Deform(Part part)
            {
                var points = new Point3DCollection(part.Original.Positions.Count);
                bool hasNormals = part.Original.Normals.Count == part.Original.Positions.Count;
                var normals = hasNormals ? new Vector3DCollection(part.Original.Normals.Count) : null;
                for (int i = 0; i < part.Original.Positions.Count; ++i)
                {
                    Point3D original = part.Original.Positions[i];
                    Vector3D normal = hasNormals ? part.Original.Normals[i] : new Vector3D();
                    Weight[] weights = part.Weights == null ? null : part.Weights[i];
                    Point3D point = new Point3D();
                    Vector3D vector = new Vector3D();
                    if (weights == null || weights.Length == 0)
                    {
                        point = skin[part.RigidBone].Transform(original);
                        if (hasNormals) vector = skin[part.RigidBone].Transform(normal);
                    }
                    else
                    {
                        foreach (Weight weight in weights)
                        {
                            Point3D value = skin[weight.Bone].Transform(original);
                            point.X += value.X * weight.Amount; point.Y += value.Y * weight.Amount; point.Z += value.Z * weight.Amount;
                            if (hasNormals) vector += skin[weight.Bone].Transform(normal) * weight.Amount;
                        }
                    }
                    points.Add(point);
                    if (hasNormals)
                    {
                        if (vector.LengthSquared > 0) vector.Normalize();
                        normals.Add(vector);
                    }
                }
                points.Freeze();
                part.Mesh.Positions = points;
                if (hasNormals)
                {
                    normals.Freeze();
                    part.Mesh.Normals = normals;
                }
            }
        }
    }
}
