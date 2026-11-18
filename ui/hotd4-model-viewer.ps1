[CmdletBinding()]
param([string] $AssetPath, [object] $Owner, [switch] $ValidateOnly)

$ErrorActionPreference = 'Stop'
$hdPack = Join-Path $PSScriptRoot 'hotd4-hd-textures'
if (!$AssetPath) {
    $install = Split-Path -Parent $PSScriptRoot
    $dumpPath = Join-Path $install 'dump-path.txt'
    if (Test-Path -LiteralPath $dumpPath -PathType Leaf) {
        $disk = [IO.File]::ReadAllText($dumpPath).Trim()
        if ($disk) { $AssetPath = Join-Path $disk 'fs' }
    }
    if (!$AssetPath) {
        $AssetPath = Join-Path $install 'game\disk0\fs'
        if (!(Test-Path -LiteralPath $AssetPath -PathType Container)) {
            $AssetPath = Join-Path $install 'The House of the Dead 4\disk0\fs'
        }
    }
}
if (!(Test-Path -LiteralPath $AssetPath -PathType Container)) {
    throw "Could not find the arcade asset folder at '$AssetPath'."
}
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
if (-not ('Hotd4Models.Catalog' -as [type])) {
    $assemblies = [System.Windows.Media.Media3D.MeshGeometry3D].Assembly.Location,
                  [System.Windows.DependencyObject].Assembly.Location
    $sources = (Join-Path $PSScriptRoot 'hotd4-models.cs'), (Join-Path $PSScriptRoot 'hotd4-model-textures.cs'),
               (Join-Path $PSScriptRoot 'hotd4-model-motion.cs')
    Add-Type -Path $sources -ReferencedAssemblies $assemblies
}
$catalog = [Hotd4Models.Catalog]::new((Resolve-Path -LiteralPath $AssetPath).Path)
if ($ValidateOnly) {
    $loaded = 0
    $triangles = 0L
    $textured = 0
    $missing = 0
    $failures = @()
    foreach ($entry in $catalog.Entries) {
        try {
            $model = [Hotd4Models.Model]::new($entry, $false)
            if (!$model.Triangles) { throw 'No indexed triangles.' }
            ++$loaded
            $triangles += $model.Triangles
            $textured += $model.TexturedMeshes
            $missing += $model.MissingTextures
        } catch {
            $failures += "$($entry.Bank)/$($entry.Name) [$($entry.Index)] $($_.Exception.GetBaseException().Message)"
        }
    }
    $catalog.BankErrors
    $failures
    "Loaded $loaded / $($catalog.Entries.Count) model entries ($triangles triangles). Empty records: $($catalog.EmptyModels). Other formats: $($catalog.OtherFormats)."
    "Indexed $($catalog.TextureCount) DDS records. Resolved $textured diffuse mesh references. Missing: $missing."
    "Indexed $($catalog.MotionCount) skeletal animation clips."
    if ($failures.Count -or $catalog.BankErrors.Count -or !$loaded) { exit 1 }
    return
}

[xml] $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HOTD4 | Model Viewer" Width="1130" Height="730" MinWidth="780" MinHeight="515"
        WindowStartupLocation="CenterScreen" Background="#11131A" Foreground="#F3F0EB" FontFamily="Segoe UI"
        UseLayoutRounding="True">
    <Window.Resources>
        <Style TargetType="TextBlock"><Setter Property="TextTrimming" Value="CharacterEllipsis"/></Style>
        <SolidColorBrush x:Key="ControlFill" Color="#232A36"/>
        <SolidColorBrush x:Key="ControlEdge" Color="#414C5F"/>
        <SolidColorBrush x:Key="HoverFill" Color="#303B4D"/>
        <SolidColorBrush x:Key="SelectedFill" Color="#263E50"/>
        <SolidColorBrush x:Key="Accent" Color="#8DCCEB"/>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{StaticResource ControlFill}"/>
            <Setter Property="Foreground" Value="#F3F0EB"/>
            <Setter Property="BorderBrush" Value="{StaticResource ControlEdge}"/>
            <Setter Property="Padding" Value="13,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Surface" CornerRadius="4" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1">
                            <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource HoverFill}"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource SelectedFill}"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Surface" Property="Opacity" Value="0.42"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#F3F0EB"/>
            <Setter Property="Padding" Value="9,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Surface" Background="Transparent" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource HoverFill}"/></Trigger>
                            <Trigger Property="IsSelected" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource SelectedFill}"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="#F3F0EB"/>
            <Setter Property="Background" Value="{StaticResource ControlFill}"/>
            <Setter Property="BorderBrush" Value="{StaticResource ControlEdge}"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="Transparent"/>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <Border x:Name="Surface" CornerRadius="4" Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" IsHitTestVisible="False">
                                <DockPanel Margin="9,0,10,0">
                                    <Path DockPanel.Dock="Right" Data="M0,0 L4,4 8,0" Stroke="{StaticResource Accent}"
                                          StrokeThickness="1.4" VerticalAlignment="Center" Margin="8,0,0,0"/>
                                    <Grid VerticalAlignment="Center" ClipToBounds="True">
                                        <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                                          ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                                          ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"/>
                                        <TextBlock x:Name="EmptyLabel" Text="{TemplateBinding Tag}" Visibility="Collapsed" Foreground="#ADB8C8"/>
                                    </Grid>
                                </DockPanel>
                            </Border>
                            <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True"
                                   IsOpen="{TemplateBinding IsDropDownOpen}" Focusable="False">
                                <Border Background="#1A212C" CornerRadius="4" BorderBrush="{StaticResource ControlEdge}"
                                        BorderThickness="1" Padding="2" MinWidth="{TemplateBinding ActualWidth}"
                                        MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <ScrollViewer CanContentScroll="True" HorizontalScrollBarVisibility="Disabled" VerticalScrollBarVisibility="Auto">
                                        <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="SelectedIndex" Value="-1"><Setter TargetName="EmptyLabel" Property="Visibility" Value="Visible"/></Trigger>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource HoverFill}"/></Trigger>
                            <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="TrackThumb" TargetType="Thumb">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border CornerRadius="4" Background="{TemplateBinding Background}"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="TrackPage" TargetType="RepeatButton">
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="#171C26" Padding="2">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Style="{StaticResource TrackPage}"/></Track.DecreaseRepeatButton>
                                <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Style="{StaticResource TrackPage}"/></Track.IncreaseRepeatButton>
                                <Track.Thumb><Thumb Background="#52617A" Style="{StaticResource TrackThumb}"/></Track.Thumb>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Slider">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Slider">
                        <Grid MinHeight="16">
                            <Border x:Name="Rail" Background="#454F62" Height="3" CornerRadius="1.5" IsHitTestVisible="False" VerticalAlignment="Center"/>
                            <Track x:Name="PART_Track">
                                <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Style="{StaticResource TrackPage}"/></Track.DecreaseRepeatButton>
                                <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Style="{StaticResource TrackPage}"/></Track.IncreaseRepeatButton>
                                <Track.Thumb><Thumb Width="11" Height="13" Background="{StaticResource Accent}" Style="{StaticResource TrackThumb}"/></Track.Thumb>
                            </Track>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Rail" Property="Background" Value="{StaticResource Accent}"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.42"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Padding" Value="9,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Surface" BorderThickness="2,0,0,0" BorderBrush="Transparent" Background="Transparent"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="{StaticResource HoverFill}"/></Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Surface" Property="Background" Value="{StaticResource SelectedFill}"/>
                                <Setter TargetName="Surface" Property="BorderBrush" Value="{StaticResource Accent}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Background="#11131A">
        <Grid.ColumnDefinitions><ColumnDefinition Width="302"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
        <Border Grid.Column="0" Padding="18,20,18,18" Background="#171A23" BorderBrush="#343845" BorderThickness="0,0,1,0">
            <DockPanel>
                <StackPanel DockPanel.Dock="Top">
                    <TextBlock Text="Model Viewer" FontSize="27" FontWeight="SemiBold" Margin="0,0,0,17"/>
                    <ComboBox x:Name="Category" Height="32" Margin="0,0,0,10" AutomationProperties.Name="Model category"/>
                    <TextBlock Text="Search names, files or banks" Foreground="#C6CAD5" Margin="1,0,0,5"/>
                    <TextBox x:Name="Search" Height="34" Padding="6,3" VerticalContentAlignment="Center"
                             Foreground="#F3F0EB" Background="#10121A" BorderBrush="#494D59" CaretBrush="#F3F0EB"/>
                    <TextBlock x:Name="Count" Margin="1,8,0,10" Foreground="#B4BAC9"/>
                </StackPanel>
                <ListBox x:Name="Entries" Background="#10121A" Foreground="#F3F0EB" BorderBrush="#343845"
                         ScrollViewer.HorizontalScrollBarVisibility="Disabled" VirtualizingPanel.IsVirtualizing="True"
                         VirtualizingPanel.IsVirtualizingWhenGrouping="True" VirtualizingPanel.VirtualizationMode="Recycling">
                    <ListBox.GroupStyle>
                        <GroupStyle>
                            <GroupStyle.HeaderTemplate>
                                <DataTemplate>
                                    <Border Background="#1D2531" Padding="11,7">
                                        <TextBlock Text="{Binding Name}" Foreground="{StaticResource Accent}" FontWeight="SemiBold"/>
                                    </Border>
                                </DataTemplate>
                            </GroupStyle.HeaderTemplate>
                        </GroupStyle>
                    </ListBox.GroupStyle>
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <StackPanel>
                                <TextBlock Text="{Binding DisplayName}" FontSize="13"/>
                                <TextBlock Text="{Binding ListDetails}" FontSize="11" Foreground="#A8AEBD" ToolTip="{Binding ListDetails}"/>
                            </StackPanel>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </DockPanel>
        </Border>
        <Grid Grid.Column="1">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <DockPanel Margin="23,18,23,14">
                <Button DockPanel.Dock="Right" x:Name="Reset" Content="Reset view" VerticalAlignment="Center" Margin="12,0,0,0"/>
                <ComboBox DockPanel.Dock="Right" x:Name="TextureMode" Height="30" MinWidth="141"
                          VerticalAlignment="Center" Margin="12,0,0,0" AutomationProperties.Name="Texture mode"
                          ToolTip="Preview locally enhanced character textures and any matching HD pack textures."/>
                <StackPanel>
                    <TextBlock x:Name="Title" FontSize="21" FontWeight="SemiBold" Foreground="#F2EFEA"/>
                    <TextBlock x:Name="Details" Foreground="#B4BAC9" Margin="0,3,0,0"/>
                </StackPanel>
            </DockPanel>
            <Border Grid.Row="1" x:Name="Canvas" ClipToBounds="True" Cursor="SizeAll" BorderBrush="#343845" BorderThickness="0,1">
                <Border.Background>
                    <RadialGradientBrush RadiusX="0.74" RadiusY="0.83">
                        <GradientStop Color="#343D49" Offset="0"/>
                        <GradientStop Color="#1B212B" Offset="0.56"/>
                        <GradientStop Color="#10131A" Offset="1"/>
                    </RadialGradientBrush>
                </Border.Background>
                <Viewport3D x:Name="Viewport" IsHitTestVisible="False" ClipToBounds="True">
                    <Viewport3D.Camera>
                        <PerspectiveCamera x:Name="Camera" Position="0,0,3.2" LookDirection="0,0,-1" UpDirection="0,1,0"
                                           FieldOfView="44" NearPlaneDistance="0.02" FarPlaneDistance="100"/>
                    </Viewport3D.Camera>
                    <ModelVisual3D>
                        <ModelVisual3D.Content>
                            <Model3DGroup>
                                <AmbientLight Color="#747883"/>
                                <DirectionalLight Color="#F2F1EE" Direction="-0.6,-0.8,-1"/>
                                <DirectionalLight Color="#818EAD" Direction="0.8,0.15,1"/>
                            </Model3DGroup>
                        </ModelVisual3D.Content>
                    </ModelVisual3D>
                    <ModelVisual3D x:Name="Object"/>
                </Viewport3D>
            </Border>
            <Border x:Name="AnimationBar" Grid.Row="2" Visibility="Collapsed" Background="#171A23" BorderBrush="#343845" BorderThickness="0,0,0,1" Padding="23,10">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <DockPanel>
                        <TextBlock DockPanel.Dock="Left" Text="Animation" Foreground="#F3F0EB" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,12,0"/>
                        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" Margin="10,0,0,0">
                            <Button x:Name="Play" Content="Play" MinWidth="67" Margin="0,0,7,0"/>
                            <Button x:Name="BindPose" Content="Bind pose"/>
                        </StackPanel>
                        <ComboBox x:Name="Clips" Tag="Bind pose" Height="30" DisplayMemberPath="Label" MaxDropDownHeight="325"
                                  AutomationProperties.Name="Animation clip"/>
                    </DockPanel>
                    <DockPanel Grid.Row="1" Margin="0,9,0,0">
                        <CheckBox DockPanel.Dock="Left" x:Name="Loop" Content="Loop" IsChecked="True" Foreground="#BEC4D1" Margin="0,0,12,0"/>
                        <TextBlock DockPanel.Dock="Right" x:Name="Position" Foreground="#BEC4D1" MinWidth="115" TextAlignment="Right" Margin="10,0,0,0"/>
                        <Slider x:Name="Timeline" Minimum="0" Maximum="1" Value="0" IsMoveToPointEnabled="True" AutomationProperties.Name="Animation timeline"/>
                    </DockPanel>
                </Grid>
            </Border>
            <DockPanel Grid.Row="3" Margin="23,13,23,14">
                <TextBlock DockPanel.Dock="Right" x:Name="TextureStatus" Foreground="#D0AC9E" Margin="18,0,0,0"/>
                <TextBlock Text="Drag  Rotate   ·   Wheel  Zoom   ·   Double-click  Reset" Foreground="#BAC0CD"/>
            </DockPanel>
        </Grid>
    </Grid>
</Window>
'@
$xmlReader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($xmlReader)
if ($Owner) {
    $window.Owner = $Owner
    $window.WindowStartupLocation = 'CenterOwner'
    $window.Topmost = $Owner.Topmost
}
$ui = @{}
foreach ($name in 'Search','Count','Category','Entries','Reset','Title','Details','Canvas','Viewport','Camera','Object',
                   'TextureStatus','TextureMode','AnimationBar','Clips','Play','BindPose','Loop','Position','Timeline') {
    $ui[$name] = $window.FindName($name)
}

$state = @{ Yaw = 22.0; Pitch = -8.0; Zoom = 1.0; Radius = 1.0; Distance = 4.0; Mouse = $null
            Rotation = $null; Pivot = $null; Model = $null; Animation = $null; Frame = 0.0; StartFrame = 0.0
            UpdatingTimeline = $false; Clock = [Diagnostics.Stopwatch]::new() }
$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(1000 / 30.0)

function Center-Geometry($Geometry) {
    $bounds = $Geometry.Bounds
    if (!$state.Pivot -or $bounds.IsEmpty) { return }
    $state.Pivot.OffsetX = -($bounds.X + $bounds.SizeX / 2)
    $state.Pivot.OffsetY = -($bounds.Y + $bounds.SizeY / 2)
    $state.Pivot.OffsetZ = -($bounds.Z + $bounds.SizeZ / 2)
}
function Pause-Animation {
    $timer.Stop()
    $state.Clock.Stop()
    $ui.Play.Content = 'Play'
}
function Reset-Animation {
    Pause-Animation
    $state.Animation = $null
    $ui.Play.IsEnabled = $false
    $ui.Timeline.IsEnabled = $false
    $ui.Loop.IsEnabled = $false
    $ui.BindPose.IsEnabled = $false
    $ui.Position.ToolTip = $null
    $ui.Position.Text = ''
    $ui.Timeline.Value = $ui.Timeline.Minimum
    if ($state.Model) {
        $ui.Object.Content = $state.Model.Geometry
        Center-Geometry $state.Model.Geometry
    }
}
function Set-AnimationFrame([double] $Frame) {
    $animation = $state.Animation
    if (!$animation) { return }
    $clip = $animation.Clip
    $state.Frame = [Math]::Max($clip.Start, [Math]::Min($clip.End, $Frame))
    $animation.SetFrame($state.Frame)
    Center-Geometry $animation.Geometry
    $state.UpdatingTimeline = $true
    try { $ui.Timeline.Value = $state.Frame }
    finally { $state.UpdatingTimeline = $false }
    $ui.Position.Text = '{0:0.00} / {1:0.00} s' -f (($state.Frame - $clip.Start) / $clip.Rate),
                                                    (($clip.End - $clip.Start) / $clip.Rate)
}
function Select-Animation($Clip) {
    Reset-Animation
    if (!$Clip -or !$state.Model) { return }
    try {
        $state.Animation = $state.Model.Animate($Clip)
        $ui.Object.Content = $state.Animation.Geometry
        $state.UpdatingTimeline = $true
        try {
            $ui.Timeline.Maximum = $Clip.End
            $ui.Timeline.Minimum = $Clip.Start
        } finally { $state.UpdatingTimeline = $false }
        Set-AnimationFrame $Clip.Start
        $ui.Play.IsEnabled = $true
        $ui.Timeline.IsEnabled = $true
        $ui.Loop.IsEnabled = $true
        $ui.BindPose.IsEnabled = $true
    } catch {
        Reset-Animation
        $ui.Position.Text = 'Clip unavailable'
        $ui.Position.ToolTip = $_.Exception.GetBaseException().Message
    }
}
function Update-View {
    $aspect = 1.45
    if ($ui.Canvas.ActualWidth -gt 0 -and $ui.Canvas.ActualHeight -gt 0) {
        $aspect = $ui.Canvas.ActualWidth / $ui.Canvas.ActualHeight
    }
    $horizontal = [Math]::Tan($ui.Camera.FieldOfView * [Math]::PI / 360)
    $edge = [Math]::Atan([Math]::Min($horizontal, $horizontal / $aspect))
    $state.Distance = 1.09 * $state.Radius * $state.Zoom / [Math]::Sin($edge)
    $ui.Camera.Position = [Windows.Media.Media3D.Point3D]::new(0, 0, $state.Distance)
    if (!$state.Rotation) { return }
    $pitch = [Windows.Media.Media3D.Quaternion]::new([Windows.Media.Media3D.Vector3D]::new(1, 0, 0), $state.Pitch)
    $yaw = [Windows.Media.Media3D.Quaternion]::new([Windows.Media.Media3D.Vector3D]::new(0, 1, 0), $state.Yaw)
    $state.Rotation.Quaternion = $pitch * $yaw
}
function Reset-View {
    $state.Yaw = 22.0
    $state.Pitch = -8.0
    $state.Zoom = 1.0
    Update-View
}
function Show-Model($Entry, [switch] $KeepView) {
    if ($KeepView) {
        $previousClips = $ui.Clips.ItemsSource
        $previousClip = $ui.Clips.SelectedItem
        $previousFrame = $state.Frame
        $wasPlaying = $timer.IsEnabled
        $previousAnimationVisibility = $ui.AnimationBar.Visibility
    }
    $state.Model = $null
    $ui.Clips.ItemsSource = $null
    $ui.AnimationBar.Visibility = 'Collapsed'
    Reset-Animation
    $state.Pivot = $null
    $state.Rotation = $null
    $ui.Object.Content = $null
    $ui.TextureStatus.Text = ''
    $ui.TextureStatus.ToolTip = $null
    if (!$Entry) {
        $ui.Title.Text = 'Select a model'
        $ui.Details.Text = ''
        return
    }
    $ui.Title.Text = $Entry.DisplayName
    try {
        $useHd = $ui.TextureMode.SelectedIndex -eq 1
        $pack = if ($useHd) { $hdPack }
        $model = [Hotd4Models.Model]::new($Entry, $true, $pack, $useHd)
        $bounds = $model.Geometry.Bounds
        if ($bounds.IsEmpty -or !$model.Triangles) { throw 'This record contains no visible geometry.' }
        $span = [Math]::Max($bounds.SizeX, [Math]::Max($bounds.SizeY, $bounds.SizeZ))
        if ($span -le 0) { throw 'This record has zero-size geometry.' }
        $scale = 2.0 / $span
        $state.Radius = $scale * 0.5 * [Math]::Sqrt(
            $bounds.SizeX * $bounds.SizeX + $bounds.SizeY * $bounds.SizeY + $bounds.SizeZ * $bounds.SizeZ)
        $transform = [Windows.Media.Media3D.Transform3DGroup]::new()
        $state.Model = $model
        $state.Pivot = [Windows.Media.Media3D.TranslateTransform3D]::new()
        Center-Geometry $model.Geometry
        $transform.Children.Add($state.Pivot)
        $transform.Children.Add([Windows.Media.Media3D.ScaleTransform3D]::new($scale, $scale, $scale))
        $state.Rotation = [Windows.Media.Media3D.QuaternionRotation3D]::new()
        $transform.Children.Add([Windows.Media.Media3D.RotateTransform3D]::new($state.Rotation))
        $ui.Object.Content = $model.Geometry
        $ui.Object.Transform = $transform
        $ui.Details.Text = '{0}.bnk   ·   Entry {1}   ·   {2:N0} triangles' -f $Entry.Bank, $Entry.Index, $model.Triangles
        if ($Entry.CharacterName) { $ui.Details.Text = $Entry.Name + '   ·   ' + $ui.Details.Text }
        $ui.TextureStatus.Text = if ($model.HdTextures -and $Entry.SupportsCharacterHd) { 'Locally enhanced textures' }
                                 elseif ($model.HdTextures) { 'HD textures applied' }
                                 elseif ($model.TexturedMeshes) { 'Original textures' }
                                 else { 'Material preview' }
        if ($model.HdTextures) {
            $ui.TextureStatus.ToolTip = if ($Entry.SupportsCharacterHd) {
                '{0} textures enhanced from this arcade dump.' -f $model.HdTextures
            } else {
                '{0} matching HD replacements. Other surfaces use the original arcade textures.' -f $model.HdTextures
            }
        } elseif ($useHd) {
            $ui.TextureStatus.ToolTip = 'HD textures are unavailable for this model.'
        }
        if ($model.MissingTextures) {
            $ui.TextureStatus.Text += ' · {0} unavailable' -f $model.MissingTextures
        }
        if ($KeepView) { Update-View } else { Reset-View }
        $clips = $previousClips
        if (!$KeepView) { $clips = $catalog.Animations($Entry) }
        if ($clips.Count) {
            $ui.Clips.ItemsSource = $clips
            $ui.AnimationBar.Visibility = 'Visible'
            if ($KeepView) {
                $ui.AnimationBar.Visibility = $previousAnimationVisibility
                $ui.Clips.SelectedItem = $previousClip
                if ($state.Animation) {
                    Set-AnimationFrame $previousFrame
                    if ($wasPlaying) { Start-Animation }
                }
            } else {
                $preferred = $clips | Sort-Object PreviewOrder, @{ Expression = { $_.Bank -ne $Entry.Bank } }, Name
                foreach ($clip in $preferred) {
                    $ui.Clips.SelectedItem = $clip
                    if ($state.Animation) { break }
                }
                if (!$state.Animation) { $ui.AnimationBar.Visibility = 'Collapsed' }
            }
        }
    } catch {
        $ui.Details.Text = $_.Exception.GetBaseException().Message
    }
}
function Update-Entries {
    $term = $ui.Search.Text.Trim()
    $category = $ui.Category.SelectedItem
    $view = [Windows.Data.CollectionViewSource]::GetDefaultView($catalog.Entries)
    $view.Filter = {
        param($entry)
        ($category -eq 'All models' -or $entry.Category -eq $category) -and
            (!$term -or $entry.Name.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
             $entry.Bank.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
             ($entry.CharacterName -and $entry.CharacterName.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0))
    }.GetNewClosure()
    $count = $ui.Entries.Items.Count
    $ui.Count.Text = switch ($count) {
        0 { 'No matching models' }
        1 { '1 model' }
        default { '{0:N0} models' -f $count }
    }
    if ($count -and !$ui.Entries.SelectedItem) { $ui.Entries.SelectedIndex = 0 }
    if ($ui.Entries.SelectedItem) { $ui.Entries.ScrollIntoView($ui.Entries.SelectedItem) }
}
$view = [Windows.Data.CollectionViewSource]::GetDefaultView($catalog.Entries)
$view.GroupDescriptions.Add([Windows.Data.PropertyGroupDescription]::new('Section'))
$ui.Entries.ItemsSource = $view
$ui.Category.ItemsSource = @('All models','Enemies','Bosses','Players','Weapons','Environments','Props & Items','Effects & UI','Other')
$ui.Category.SelectedIndex = 0
$ui.Entries.Add_SelectionChanged({ Show-Model $ui.Entries.SelectedItem })
$ui.Search.Add_TextChanged({ Update-Entries })
$ui.Category.Add_SelectionChanged({ Update-Entries })
$ui.Clips.Add_SelectionChanged({ Select-Animation $ui.Clips.SelectedItem })
$ui.BindPose.Add_Click({ $ui.Clips.SelectedIndex = -1 })
function Start-Animation {
    if (!$state.Animation) { return }
    if ($state.Frame -ge $state.Animation.Clip.End) { Set-AnimationFrame $state.Animation.Clip.Start }
    $state.StartFrame = $state.Frame
    $state.Clock.Restart()
    $timer.Start()
    $ui.Play.Content = 'Pause'
}
$ui.Play.Add_Click({
    if ($timer.IsEnabled) { Pause-Animation } else { Start-Animation }
})
$ui.TextureMode.ItemsSource = @('Original textures','HD textures')
$ui.TextureMode.SelectedIndex = 0
$ui.TextureMode.Add_SelectionChanged({
    if ($state.Model) { Show-Model $ui.Entries.SelectedItem -KeepView }
})
$ui.Timeline.Add_ValueChanged({
    if ($state.UpdatingTimeline -or !$state.Animation) { return }
    Set-AnimationFrame $ui.Timeline.Value
    if ($timer.IsEnabled) { $state.StartFrame = $state.Frame; $state.Clock.Restart() }
})
$timer.Add_Tick({
    if (!$state.Animation) { Pause-Animation; return }
    $clip = $state.Animation.Clip
    $frame = $state.StartFrame + $state.Clock.Elapsed.TotalSeconds * $clip.Rate
    if ($frame -ge $clip.End) {
        if ($ui.Loop.IsChecked) { $frame = $clip.Start + ($frame - $clip.Start) % ($clip.End - $clip.Start) }
        else { $frame = $clip.End; Pause-Animation }
    }
    Set-AnimationFrame $frame
})
$window.Add_Closed({ Pause-Animation })
$ui.Reset.Add_Click({ Reset-View })
$ui.Canvas.Add_MouseLeftButtonDown({
    param($sender, $eventArgs)
    if ($eventArgs.ClickCount -eq 2) { Reset-View; return }
    $state.Mouse = $eventArgs.GetPosition($ui.Canvas)
    [void]$ui.Canvas.CaptureMouse()
})
$ui.Canvas.Add_MouseMove({
    param($sender, $eventArgs)
    if ($null -eq $state.Mouse) { return }
    $point = $eventArgs.GetPosition($ui.Canvas)
    $state.Yaw = ($state.Yaw + ($point.X - $state.Mouse.X) * 0.48) % 360
    $state.Pitch = ($state.Pitch + ($point.Y - $state.Mouse.Y) * 0.48) % 360
    $state.Mouse = $point
    Update-View
})
$ui.Canvas.Add_MouseLeftButtonUp({ $state.Mouse = $null; $ui.Canvas.ReleaseMouseCapture() })
$ui.Canvas.Add_LostMouseCapture({ $state.Mouse = $null })
$ui.Canvas.Add_MouseWheel({
    param($sender, $eventArgs)
    $state.Zoom = [Math]::Max(0.12, [Math]::Min(5.0, $state.Zoom * [Math]::Pow(0.85, $eventArgs.Delta / 120.0)))
    Update-View
})
$ui.Canvas.Add_SizeChanged({ Update-View })
$window.Add_KeyDown({ param($sender,$eventArgs) if ($eventArgs.Key -eq 'Escape') { $window.Close() } })
Update-Entries
[void]$window.ShowDialog()
