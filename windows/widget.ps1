Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class daakLOLILEIconNative {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
'@

$createdNew = $false
$widgetMutex = New-Object System.Threading.Mutex($true, 'Local\daakLOLILEWidget', [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="252" Height="132" FontFamily="Segoe UI"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowActivated="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Border CornerRadius="14" Background="#F215131A" BorderBrush="#3A3441" BorderThickness="1" Padding="11">
    <Border.Effect>
      <DropShadowEffect BlurRadius="24" ShadowDepth="7" Opacity="0.34" Color="#000000"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Ellipse x:Name="StatusDot" Width="7" Height="7" Fill="#E9B95D" Margin="0,1,8,0"/>
        <StackPanel Grid.Column="1">
          <TextBlock Text="daakLOLILE" Foreground="#8E8796" FontSize="7" FontWeight="SemiBold"/>
          <TextBlock x:Name="StatusText" Text="Ba&#x011F;lan&#x0131;yor" Foreground="#F4F1F6" FontSize="12" FontWeight="SemiBold"/>
        </StackPanel>
        <Button x:Name="OpenButton" Grid.Column="2" Content="&#x2197;" Width="20" Height="20" Margin="0,0,4,0"
                Foreground="#C69BEA" Background="#211D27" BorderBrush="#3A3342"
                ToolTip="B&#x00FC;y&#x00FC;k paneli a&#x00E7;" Cursor="Hand"/>
        <Button x:Name="CloseButton" Grid.Column="3" Content="&#x00D7;" Width="20" Height="20"
                Foreground="#9B94A3" Background="#211D27" BorderBrush="#3A3342"
                ToolTip="Widget'&#x0131; sistem tepsisine gizle" Cursor="Hand"/>
      </Grid>

      <Grid Grid.Row="1" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="UsageText" Text="&#x2014;" Foreground="#F4F1F6" FontSize="20" FontWeight="SemiBold"/>
        <TextBlock x:Name="UsageMetaText" Grid.Column="1" Text="TOPLAM DESTEK" Foreground="#918999"
                   FontSize="8" FontWeight="SemiBold" VerticalAlignment="Bottom" Margin="0,0,0,3"/>
      </Grid>

      <TextBlock x:Name="NetworkText" Grid.Row="2" Text="Tor &#x2014; &#x00B7; Snowflake &#x2014;"
                 Foreground="#BDB6C3" FontSize="9" Margin="0,8,0,0" TextTrimming="CharacterEllipsis"/>
      <TextBlock x:Name="ResourceText" Grid.Row="3" Text="PC &#x2014; &#x00B7; Bilim &#x2014;"
                 Foreground="#9B94A3" FontFamily="Cascadia Mono" FontSize="8" Margin="0,7,0,0"
                 TextTrimming="CharacterEllipsis"/>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
foreach ($name in @(
    'StatusDot','StatusText','UsageText','UsageMetaText','NetworkText','ResourceText',
    'OpenButton','CloseButton'
)) {
    Set-Variable -Name ($name.Substring(0,1).ToLower() + $name.Substring(1)) -Value $window.FindName($name)
}

function Format-Bytes([double]$bytes) {
    $units = @('B', 'KB', 'MB', 'GB', 'TB')
    $index = 0
    while ($bytes -ge 1000 -and $index -lt ($units.Count - 1)) {
        $bytes /= 1000
        $index++
    }
    $digits = if ($bytes -ge 100) { 0 } elseif ($bytes -ge 10) { 1 } else { 2 }
    return ('{0:N' + $digits + '} {1}') -f $bytes, $units[$index]
}

function Convert-UnicodeLiteral([string]$Text) {
    return [regex]::Replace($Text, '\\u([0-9A-Fa-f]{4})', {
        param($match)
        return [string][char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function New-StatusIcon([string]$Color) {
    $bitmap = New-Object Drawing.Bitmap 16, 16
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::Transparent)
    $brush = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml($Color))
    $border = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(210, 24, 20, 28)), 1
    $graphics.FillEllipse($brush, 2, 2, 12, 12)
    $graphics.DrawEllipse($border, 2, 2, 12, 12)
    $handle = $bitmap.GetHicon()
    $icon = [Drawing.Icon]::FromHandle($handle).Clone()
    [void][daakLOLILEIconNative]::DestroyIcon($handle)
    $border.Dispose()
    $brush.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    return $icon
}

$ui = @{
    ActiveOpen = Convert-UnicodeLiteral 'Aktif \u00B7 NAT a\u00E7\u0131k'
    ActiveDemand = Convert-UnicodeLiteral 'Aktif \u00B7 talebe g\u00F6re'
    Closed = Convert-UnicodeLiteral 'Kapal\u0131'
    Dash = Convert-UnicodeLiteral '\u2014'
    Degree = Convert-UnicodeLiteral '\u00B0'
    Infinity = Convert-UnicodeLiteral '\u221E'
    MiddleDot = Convert-UnicodeLiteral '\u00B7'
    Lira = Convert-UnicodeLiteral '\u20BA'
    RelayOnline = Convert-UnicodeLiteral 'Relay \u00E7evrimi\u00E7i'
    Unlimited = Convert-UnicodeLiteral 's\u0131n\u0131rs\u0131z'
    NotYet = Convert-UnicodeLiteral 'Hen\u00FCz yok'
    SciencePreparing = Convert-UnicodeLiteral 'Bilim: kurulum/kay\u0131t haz\u0131rlan\u0131yor'
    PanelOffline = Convert-UnicodeLiteral 'Panel ba\u011Flant\u0131s\u0131 yok'
    Reconnecting = Convert-UnicodeLiteral 'Yeniden ba\u011Flan\u0131yor'
    Waiting = Convert-UnicodeLiteral 'bekliyor'
    TrayToggle = Convert-UnicodeLiteral 'Widget''i g\u00F6ster / gizle'
    TrayOpen = Convert-UnicodeLiteral 'Paneli a\u00E7'
    TrayExit = Convert-UnicodeLiteral '\u00C7\u0131k\u0131\u015F'
}

$script:widgetFailures = 0
$script:lastWidgetSuccess = [DateTime]::MinValue
$script:trayColor = ''
$script:trayIconCurrent = $null

$notifyIcon = New-Object Windows.Forms.NotifyIcon
$notifyIcon.Text = 'daakLOLILE'
$notifyIcon.Icon = New-StatusIcon '#E9B95D'
$script:trayIconCurrent = $notifyIcon.Icon
$script:trayColor = '#E9B95D'
$notifyIcon.Visible = $true

function Set-TrayState([string]$Color, [string]$Text) {
    if ($script:trayColor -ne $Color) {
        $newIcon = New-StatusIcon $Color
        $oldIcon = $script:trayIconCurrent
        $notifyIcon.Icon = $newIcon
        $script:trayIconCurrent = $newIcon
        $script:trayColor = $Color
        if ($oldIcon) { $oldIcon.Dispose() }
    }
    $safeText = if ($Text.Length -gt 63) { $Text.Substring(0, 63) } else { $Text }
    $notifyIcon.Text = $safeText
}

function Toggle-WidgetVisibility {
    if ($window.IsVisible) {
        $window.Hide()
    }
    else {
        Ensure-WidgetVisible
        $window.Show()
        $window.Topmost = $true
        $window.Activate() | Out-Null
    }
}

function Update-Widget {
    try {
        $data = Invoke-RestMethod -Uri 'http://127.0.0.1:17657/api/status' -TimeoutSec 5
        $script:widgetFailures = 0
        $script:lastWidgetSuccess = Get-Date
        $relayOnline = $data.service.running -and $data.port.listening -and $data.bootstrap -ge 100
        $snowflakeOnline = $data.snowflake.running -eq $true
        $activeProjects = [int]$data.support.activeProjects
        $supportOnline = $relayOnline -or $snowflakeOnline -or $activeProjects -gt 0
        $statusDot.Fill = if ($supportOnline) { '#64D692' } else { '#EF7D7D' }
        $statusText.Text = if ($relayOnline -and $snowflakeOnline) {
            'Tor + Snowflake aktif'
        } elseif ($snowflakeOnline) {
            'Snowflake aktif'
        } elseif ($relayOnline) {
            $ui.RelayOnline
        } else {
            'Kontrol gerekli'
        }

        $unlimited = -not [double]$data.traffic.quota
        $supportTotal = if ($null -ne $data.support.total) { [double]$data.support.total } else { [double]$data.traffic.total }
        $usageText.Text = Format-Bytes $supportTotal
        $usageMetaText.Text = if ($unlimited) {
            'SINIRSIZ'
        } else {
            "KOTA $(Format-Bytes ([double]$data.traffic.quota))"
        }
        $projectLabels = @()
        if ($data.volunteer.folding.running) { $projectLabels += 'FAH' }
        if ($data.volunteer.boinc.running -and @($data.volunteer.boinc.projects).Count -gt 0) { $projectLabels += 'BOINC' }
        if ($data.volunteer.ripeAtlas.running) { $projectLabels += 'RIPE' }
        $torSummary = if ($relayOnline) { "Tor %$($data.bootstrap)" } else { "Tor $($ui.Waiting)" }
        $snowflakeSummary = if ($snowflakeOnline) {
            if ($data.snowflake.natType -eq 'unrestricted') { Convert-UnicodeLiteral 'Snowflake a\u00E7\u0131k' } else { 'Snowflake aktif' }
        } else { "Snowflake $($ui.Closed)" }
        $projectSummary = if ($projectLabels.Count) { $projectLabels -join '+' } else { "$activeProjects/4 aktif" }
        $networkText.Text = "$torSummary $($ui.MiddleDot) $snowflakeSummary $($ui.MiddleDot) $projectSummary"

        if ($data.hardware.available -eq $true) {
            $modeLabel = switch ([string]$data.power.effectiveMode) {
                'eco' { 'EKO' }
                'performance' { 'HIZ' }
                'balanced' { 'DENGE' }
                default { $ui.Dash }
            }
            $gpuValue = if ($null -ne $data.hardware.gpu.temperatureC) {
                "$([Math]::Round([double]$data.hardware.gpu.temperatureC))$($ui.Degree)"
            } else {
                "%$([Math]::Round([double]$data.hardware.gpu.loadPercent))"
            }
            $resourceText.Text = "$([Math]::Round([double]$data.hardware.power.wallEstimateWatts)) W $modeLabel $($ui.MiddleDot) CPU %$([Math]::Round([double]$data.hardware.cpu.loadPercent)) $($ui.MiddleDot) GPU $gpuValue"
        } else {
            $resourceText.Text = "PC $($ui.Dash)"
        }
        $trayColor = if ($supportOnline) { '#64D692' } else { '#EF7D7D' }
        Set-TrayState $trayColor "daakLOLILE | $($statusText.Text) | $($usageText.Text) | $($resourceText.Text)"
    } catch {
        $script:widgetFailures++
        $recentSuccess = $script:lastWidgetSuccess -gt [DateTime]::MinValue -and
            ((Get-Date) - $script:lastWidgetSuccess).TotalSeconds -lt 30
        if ($recentSuccess -or $script:widgetFailures -lt 3) {
            $statusDot.Fill = '#E9B95D'
            Set-TrayState '#E9B95D' "daakLOLILE | $($ui.Reconnecting)"
            return
        }
        $statusDot.Fill = '#EF7D7D'
        $statusText.Text = $ui.Reconnecting
        $usageText.Text = $ui.Dash
        $usageMetaText.Text = ''
        $networkText.Text = "Tor $($ui.Dash) $($ui.MiddleDot) Snowflake $($ui.Dash)"
        $resourceText.Text = "PC $($ui.Dash)"
        Set-TrayState '#EF7D7D' "daakLOLILE | $($ui.Reconnecting)"
    }
}

function Move-WidgetToCorner {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $window.Left = $workArea.Right - $window.Width - 22
    $window.Top = $workArea.Bottom - $window.Height - 22
}

function Ensure-WidgetVisible {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $outside = (
        $window.Left -lt $workArea.Left -or
        $window.Top -lt $workArea.Top -or
        ($window.Left + $window.Width) -gt $workArea.Right -or
        ($window.Top + $window.Height) -gt $workArea.Bottom
    )
    if ($outside) {
        Move-WidgetToCorner
    }
}

Move-WidgetToCorner
$window.Add_Loaded({
    Move-WidgetToCorner
    $window.Topmost = $true
    $window.Activate() | Out-Null
})
$displaySettingsHandler = [System.EventHandler]{
    $window.Dispatcher.BeginInvoke(
        [Action]{
            Move-WidgetToCorner
            $window.Topmost = $true
        }
    ) | Out-Null
}
[Microsoft.Win32.SystemEvents]::add_DisplaySettingsChanged($displaySettingsHandler)
$window.Add_Closed({
    [Microsoft.Win32.SystemEvents]::remove_DisplaySettingsChanged($displaySettingsHandler)
})
$window.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $window.DragMove()
    }
})
$window.Add_MouseDoubleClick({ Start-Process 'http://127.0.0.1:17657' })
$openButton.Add_Click({ Start-Process 'http://127.0.0.1:17657' })
$closeButton.Add_Click({ $window.Hide() })

$script:allowClose = $false
$window.Add_Closing({
    param($sender, $eventArgs)
    if (-not $script:allowClose) {
        $eventArgs.Cancel = $true
        $window.Hide()
    }
})

$trayMenu = New-Object Windows.Forms.ContextMenuStrip
$toggleMenuItem = $trayMenu.Items.Add($ui.TrayToggle)
$openMenuItem = $trayMenu.Items.Add($ui.TrayOpen)
[void]$trayMenu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$exitMenuItem = $trayMenu.Items.Add($ui.TrayExit)
$notifyIcon.ContextMenuStrip = $trayMenu

$toggleMenuItem.add_Click({
    $window.Dispatcher.BeginInvoke([Action]{ Toggle-WidgetVisibility }) | Out-Null
})
$openMenuItem.add_Click({ Start-Process 'http://127.0.0.1:17657' })
$exitMenuItem.add_Click({
    $window.Dispatcher.BeginInvoke([Action]{
        $script:allowClose = $true
        $window.Close()
    }) | Out-Null
})
$notifyIcon.add_MouseClick({
    param($sender, $eventArgs)
    if ($eventArgs.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $window.Dispatcher.BeginInvoke([Action]{ Toggle-WidgetVisibility }) | Out-Null
    }
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({
    Ensure-WidgetVisible
    Update-Widget
})
Update-Widget
$timer.Start()
try {
    $window.ShowDialog() | Out-Null
}
finally {
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $trayMenu.Dispose()
    if ($script:trayIconCurrent) { $script:trayIconCurrent.Dispose() }
    $widgetMutex.ReleaseMutex()
    $widgetMutex.Dispose()
}
