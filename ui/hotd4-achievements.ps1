function Update-Hotd4Achievements {
    param($Controls,[string]$RecompDir,[ValidateSet('All','Unlocked','Locked')][string]$Filter='All')
    $rows=@(
        @('ESCAPE','Clear CHAPTER 1 on any difficulty.','bronze'),
        @('LOST','Clear CHAPTER 2 on any difficulty.','bronze'),
        @('EMPTINESS','Clear CHAPTER 3 on any difficulty.','bronze'),
        @('DESPAIR','Clear CHAPTER 4 on any difficulty.','bronze'),
        @('REUNION','Clear CHAPTER 5 on any difficulty.','bronze'),
        @('HOPE','Clear CHAPTER 6 on any difficulty.','bronze'),
        @('EAT THIS!!!','During CHAPTER 1 Boss encounter, throw a grenade and damage JUSTICE.','bronze'),
        @('CUT THE WIRE','During CHAPTER 2, cut the wire and let the enemies fall.','bronze'),
        @('BONUS EXPLORER','Find a secret room.','bronze'),
        @('GET THE BUS','Shoot and destroy the BUS.','bronze'),
        @("PANDORA'S BOX",'See all 4 endings of THE HOUSE OF THE DEAD 4.','gold'),
        @('TOP AGENT','Get RANK 2 or above in Final Result.','silver')
    )
    $unlocked=@{};$endingMask=0
    $file=Join-Path $RecompDir 'achievements.txt'
    if([IO.File]::Exists($file)) {
        $lines=[IO.File]::ReadAllLines($file)
        if($lines.Count -gt 0 -and $lines[0] -eq 'HOTD4-ACHIEVEMENTS-1') {
            foreach($line in $lines) {
                if($line -match '^endings (\d+)$'){$endingMask=[int]$Matches[1] -band 15}
                if($line -match '^(\d+) (\d+)$' -and [int]$Matches[1] -lt 12 -and [long]$Matches[2] -gt 0){$unlocked[[int]$Matches[1]]=[long]$Matches[2]}
            }
        }
    }
    $endingCount=0;foreach($bit in 0..3){if($endingMask -band (1 -shl $bit)){$endingCount++}}
    $Controls.AchievementProgress.Text="$($unlocked.Count) / 12 unlocked"
    $Controls.AchievementTotal.Text="$($unlocked.Count) / 12"
    $percent=[int][Math]::Round($unlocked.Count*100.0/12)
    $Controls.AchievementPercent.Text="$percent% complete"
    $Controls.AchievementProgressFill.Width=180*$unlocked.Count/12.0
    $Controls.AchievementEndings.Text="$endingCount / 4 endings seen"
    $brush={param($hex) [Windows.Media.BrushConverter]::new().ConvertFromString($hex)}
    foreach($metal in 'Bronze','Silver','Gold') {
        $tier=$metal.ToLowerInvariant();$count=0
        foreach($id in $unlocked.Keys){if($rows[[int]$id][2] -eq $tier){$count++}}
        $max=if($tier -eq 'bronze'){10}else{1}
        $Controls["Achievement${metal}Count"].Text="$count / $max"
        $Controls["Achievement${metal}Icon"].Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $RecompDir "achievement-assets/$tier.png"))
        $Controls["Achievement${metal}Icon"].Opacity=if($count){1}else{0.38}
    }
    $Controls.AchievementEmptyStar.Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $RecompDir 'achievement-assets/bronze.png'))
    $Controls.AchievementUnlocked.Content="Unlocked ($($unlocked.Count))"
    $Controls.AchievementLocked.Content="Locked ($(12-$unlocked.Count))"
    foreach($tab in 'All','Unlocked','Locked'){
        $button=$Controls["Achievement$tab"]
        $button.Background=& $brush $(if($tab -eq $Filter){'#684C2B'}else{'#1B202B'})
        $button.BorderBrush=& $brush $(if($tab -eq $Filter){'#DEB476'}else{'#414653'})
        $button.Foreground=& $brush $(if($tab -eq $Filter){'#FFF0D1'}else{'#C4CBD6'})
    }
    $ids=@(switch($Filter){
        'Unlocked' {0..11 | Where-Object {$unlocked.ContainsKey($_)}}
        'Locked' {0..11 | Where-Object {!$unlocked.ContainsKey($_)}}
        default {0..11}
    })
    $Controls.AchievementsPage.Tag=$Filter
    $Controls.AchievementList.Children.Clear()
    $Controls.AchievementEmptyPanel.Visibility=if($ids.Count){'Collapsed'}else{'Visible'}
    $Controls.AchievementEmpty.Text=if($Filter -eq 'Locked'){'All trophies unlocked'}else{'No trophies unlocked yet'}
    $Controls.AchievementEmptyHint.Text=if($Filter -eq 'Locked'){'Your base-game collection is complete.'}else{'Clear a chapter to earn your first star.'}
    foreach($id in $ids) {
        $name,$description,$metal=$rows[$id]
        $earned=$unlocked.ContainsKey($id)
        $tierColors=@{bronze='#D69B70';silver='#C5D2E1';gold='#EAC47D'}
        $border=[Windows.Controls.Border]::new();$border.Tag=@{Id=$id;Unlocked=$earned;Tier=$metal}
        $border.Background=& $brush $(if($earned){'#20232B'}else{'#131923'})
        $border.BorderBrush=& $brush $(if($earned){'#A98954'}else{'#303A49'})
        $border.BorderThickness=[Windows.Thickness]::new(1);$border.CornerRadius=[Windows.CornerRadius]::new(5)
        $border.Padding=[Windows.Thickness]::new(13);$border.Margin=[Windows.Thickness]::new(0,0,12,12)
        $border.MinHeight=168
        [Windows.Automation.AutomationProperties]::SetName($border,"$name. $description. "+$(if($earned){'Unlocked'}else{'Locked'}))
        $grid=[Windows.Controls.Grid]::new()
        foreach($height in '64','*','23'){$row=[Windows.Controls.RowDefinition]::new();$row.Height=[Windows.GridLengthConverter]::new().ConvertFromString($height);[void]$grid.RowDefinitions.Add($row)}
        $header=[Windows.Controls.Grid]::new()
        foreach($width in '66','*'){$col=[Windows.Controls.ColumnDefinition]::new();$col.Width=[Windows.GridLengthConverter]::new().ConvertFromString($width);[void]$header.ColumnDefinitions.Add($col)}
        $icon=[Windows.Controls.Image]::new();$icon.Width=56;$icon.Height=56;$icon.HorizontalAlignment='Left'
        $icon.Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $RecompDir "achievement-assets/$metal.png"));$icon.Opacity=if($earned){1}else{0.28}
        [void]$header.Children.Add($icon)
        $text=[Windows.Controls.StackPanel]::new();$text.VerticalAlignment='Center';[Windows.Controls.Grid]::SetColumn($text,1)
        $title=[Windows.Controls.TextBlock]::new();$title.Text=$name;$title.FontSize=17;$title.FontWeight='SemiBold';$title.TextWrapping='Wrap';$title.Foreground=& $brush $(if($earned){'#F6D49B'}else{'#DFE4EC'})
        $status=[Windows.Controls.TextBlock]::new();$status.FontSize=11;$status.FontWeight='SemiBold';$status.Margin=[Windows.Thickness]::new(0,5,0,0)
        $status.Text=if($earned){'UNLOCKED'}else{'LOCKED'}
        $status.Foreground=& $brush $(if($earned){'#D7B378'}else{'#8D99AD'})
        [void]$text.Children.Add($title);[void]$text.Children.Add($status);[void]$header.Children.Add($text);[void]$grid.Children.Add($header)
        $detail=[Windows.Controls.TextBlock]::new();$detail.Text=$description;$detail.FontSize=13;$detail.TextWrapping='Wrap';$detail.Foreground=& $brush '#B9C2D0';$detail.Margin=[Windows.Thickness]::new(0,8,0,7)
        [Windows.Controls.Grid]::SetRow($detail,1);[void]$grid.Children.Add($detail)
        $footer=[Windows.Controls.Grid]::new();[Windows.Controls.Grid]::SetRow($footer,2)
        $tier=[Windows.Controls.TextBlock]::new();$tier.Text=$metal.ToUpperInvariant()+' STAR';$tier.FontSize=10;$tier.FontWeight='SemiBold';$tier.VerticalAlignment='Bottom';$tier.Foreground=& $brush $tierColors[$metal]
        [void]$footer.Children.Add($tier)
        $date=[Windows.Controls.TextBlock]::new();$date.FontSize=10;$date.VerticalAlignment='Bottom';$date.HorizontalAlignment='Right';$date.Foreground=& $brush '#98A5B8'
        $date.Text=if($earned){[DateTimeOffset]::FromUnixTimeSeconds($unlocked[$id]).LocalDateTime.ToString('yyyy-MM-dd HH:mm')}else{''}
        [void]$footer.Children.Add($date);[void]$grid.Children.Add($footer)
        $border.Child=$grid;[void]$Controls.AchievementList.Children.Add($border)
    }
    $Controls.AchievementScroll.ScrollToTop()
}
