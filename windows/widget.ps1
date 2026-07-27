Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$createdNew = $false
$widgetMutex = New-Object System.Threading.Mutex($true, 'Local\daakLOLILEWidget', [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="270" Height="167" FontFamily="Segoe UI"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Border CornerRadius="14" Background="#F215131A" BorderBrush="#3A3441" BorderThickness="1"
          Padding="12">
    <Border.Effect>
      <DropShadowEffect BlurRadius="28" ShadowDepth="8" Opacity="0.38" Color="#000000"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
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
          <TextBlock Text="daakLOLILE · SİSTEM DESTEĞİ" Foreground="#9B94A3" FontSize="8" FontWeight="SemiBold"/>
          <TextBlock x:Name="StatusText" Text="Bağlanıyor" Foreground="#F4F1F6" FontSize="14"
                     FontWeight="SemiBold" Margin="0,1,0,0"/>
        </StackPanel>
        <Button x:Name="OpenButton" Grid.Column="2" Content="&#x2197;" Width="24" Height="24" Margin="0,0,4,0"
                Foreground="#C69BEA" Background="#211D27" BorderBrush="#3A3342"
                ToolTip="Büyük paneli aç" Cursor="Hand"/>
        <Button x:Name="CloseButton" Grid.Column="3" Content="&#x00D7;" Width="24" Height="24"
                Foreground="#9B94A3" Background="#211D27" BorderBrush="#3A3342"
                ToolTip="Widget'ı kapat" Cursor="Hand"/>
      </Grid>

      <Grid Grid.Row="1" Margin="0,9,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="TOPLAM DESTEK" Foreground="#777080" FontSize="8" FontWeight="SemiBold"/>
          <TextBlock x:Name="UsageText" Text="—" Foreground="#F4F1F6" FontSize="15"
                     FontWeight="SemiBold" Margin="0,1,0,0"/>
        </StackPanel>
        <TextBlock x:Name="PercentText" Grid.Column="1" Text="—" Foreground="#C69BEA"
                   FontFamily="Consolas" FontSize="10" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
      </Grid>

      <Grid Grid.Row="2" Height="5" Margin="0,6,0,0" ClipToBounds="True">
        <Border Background="#29242F" CornerRadius="3"/>
        <Border x:Name="ProgressFill" Background="#A875D2" CornerRadius="3"
                HorizontalAlignment="Left" Width="0"/>
      </Grid>

      <Grid Grid.Row="3" Margin="0,9,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="TOR" Foreground="#777080" FontSize="8"/>
          <TextBlock x:Name="BootstrapText" Text="—" Foreground="#D5CFD9" FontSize="9" Margin="0,2,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <TextBlock Text="YARDIM" Foreground="#777080" FontSize="8"/>
          <TextBlock x:Name="PortText" Text="—" Foreground="#D5CFD9" FontSize="9" Margin="0,2,0,0"
                     ToolTip="Snowflake üzerinden başarıyla tamamlanan bağlantı sayısı"/>
        </StackPanel>
        <StackPanel Grid.Column="2">
          <TextBlock Text="CONSENSUS" Foreground="#777080" FontSize="8"/>
          <TextBlock x:Name="ConsensusText" Text="—" Foreground="#D5CFD9" FontSize="9" Margin="0,2,0,0"/>
        </StackPanel>
      </Grid>

      <Grid Grid.Row="4" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="PowerText" Text="PC —" Foreground="#C69BEA" FontFamily="Consolas" FontSize="9"/>
        <TextBlock x:Name="CpuText" Grid.Column="1" Text="CPU —" Foreground="#D5CFD9" FontFamily="Consolas" FontSize="9"/>
        <TextBlock x:Name="GpuText" Grid.Column="2" Text="GPU —" Foreground="#D5CFD9" FontFamily="Consolas" FontSize="9"/>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$statusDot = $window.FindName('StatusDot')
$statusText = $window.FindName('StatusText')
$usageText = $window.FindName('UsageText')
$percentText = $window.FindName('PercentText')
$progressFill = $window.FindName('ProgressFill')
$bootstrapText = $window.FindName('BootstrapText')
$portText = $window.FindName('PortText')
$consensusText = $window.FindName('ConsensusText')
$powerText = $window.FindName('PowerText')
$cpuText = $window.FindName('CpuText')
$gpuText = $window.FindName('GpuText')
$openButton = $window.FindName('OpenButton')
$closeButton = $window.FindName('CloseButton')

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

function Update-Widget {
    try {
        $data = Invoke-RestMethod -Uri 'http://127.0.0.1:17657/api/status' -TimeoutSec 4
        $relayOnline = $data.service.running -and $data.port.listening -and $data.bootstrap -ge 100
        $snowflakeOnline = $data.snowflake.running -eq $true
        $supportOnline = $relayOnline -or $snowflakeOnline
        $statusDot.Fill = if ($supportOnline) { '#64D692' } else { '#EF7D7D' }
        $statusText.Text = if ($relayOnline -and $snowflakeOnline) {
            'Tor + Snowflake aktif'
        } elseif ($relayOnline) {
            'Relay çevrimiçi'
        } elseif ($snowflakeOnline) {
            'Snowflake aktif'
        } else {
            'Kontrol gerekli'
        }
        $unlimited = -not [double]$data.traffic.quota
        $supportTotal = if ($null -ne $data.support.total) { [double]$data.support.total } else { [double]$data.traffic.total }
        $usageText.Text = if ($unlimited) { "$(Format-Bytes $supportTotal) · sınırsız" } else { "$(Format-Bytes $supportTotal) / $(Format-Bytes ([double]$data.traffic.quota))" }
        $percent = [Math]::Min(100, [Math]::Max(0, [double]$data.traffic.percent))
        $percentText.Text = if ($unlimited) { '∞' } elseif ($percent -lt 1) { "%$($percent.ToString('0.000'))" } else { "%$($percent.ToString('0.0'))" }
        $progressFill.Width = if ($unlimited) { 246 } else { [Math]::Max(1, 246 * $percent / 100) }
        $progressFill.Opacity = if ($unlimited) { 0.28 } else { 1 }
        $bootstrapText.Text = if ($relayOnline) { "%$($data.bootstrap) · $($data.port.number)" } else { 'Kapalı' }
        $completedConnections = [int]$data.snowflake.traffic.connections
        $portText.Text = if ($snowflakeOnline) { "$completedConnections bağlantı" } else { 'Kapalı' }
        $consensusText.Text = if ($data.consensus.running) { 'Listede' } elseif ($data.consensus.found) { 'Bekliyor' } else { 'Henüz yok' }
        if ($data.hardware.available -eq $true) {
            $modeLabel = switch ([string]$data.power.effectiveMode) {
                'eco' { 'EKO' }
                'performance' { 'HIZ' }
                'balanced' { 'DENGE' }
                default { '—' }
            }
            $powerText.Text = "$([Math]::Round([double]$data.hardware.power.wallEstimateWatts)) W · $modeLabel"
            $cpuText.Text = "CPU %$([Math]::Round([double]$data.hardware.cpu.loadPercent))"
            $gpuTemp = if ($null -ne $data.hardware.gpu.temperatureC) { "$([Math]::Round([double]$data.hardware.gpu.temperatureC))°" } else { "%$([Math]::Round([double]$data.hardware.gpu.loadPercent))" }
            $gpuText.Text = "GPU $gpuTemp"
        } else {
            $powerText.Text = 'PC —'
            $cpuText.Text = 'CPU —'
            $gpuText.Text = 'GPU —'
        }
    } catch {
        $statusDot.Fill = '#EF7D7D'
        $statusText.Text = 'Panel bağlantısı yok'
        $bootstrapText.Text = '—'
        $portText.Text = '—'
        $consensusText.Text = '—'
        $powerText.Text = 'PC —'
        $cpuText.Text = 'CPU —'
        $gpuText.Text = 'GPU —'
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
$window.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $window.DragMove()
    }
})
$window.Add_MouseDoubleClick({ Start-Process 'http://127.0.0.1:17657' })
$openButton.Add_Click({ Start-Process 'http://127.0.0.1:17657' })
$closeButton.Add_Click({ $window.Close() })

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({
    Ensure-WidgetVisible
    Update-Widget
})
Update-Widget
$timer.Start()
$window.ShowDialog() | Out-Null
