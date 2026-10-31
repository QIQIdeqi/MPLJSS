$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Text = 'Wolai MCP Token'
$form.Width = 540
$form.Height = 190
$form.StartPosition = 'CenterScreen'
$label = New-Object Windows.Forms.Label
$label.Text = 'Paste the Token from Wolai Settings > MCP. It stays on this PC.'
$label.SetBounds(15,15,500,30)
$box = New-Object Windows.Forms.TextBox
$box.UseSystemPasswordChar = $true
$box.SetBounds(15,55,490,25)
$save = New-Object Windows.Forms.Button
$save.Text = 'Save'
$save.SetBounds(405,95,100,30)
$save.DialogResult = [Windows.Forms.DialogResult]::OK
$form.Controls.AddRange(@($label,$box,$save))
$form.AcceptButton = $save
if ($form.ShowDialog() -eq [Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($box.Text)) {
    [Environment]::SetEnvironmentVariable('WOLAI_MCP_TOKEN', $box.Text.Trim(), 'User')
    $box.Clear()
    [Windows.Forms.MessageBox]::Show('Token saved. Fully exit and restart Codex to load the connection.', 'Wolai MCP') | Out-Null
}
$form.Dispose()
