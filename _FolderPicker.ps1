# Shared modern folder picker (Vista IFileOpenDialog), extracted from 'Transcribe Folder.ps1'.
# Dot-source this file, then call Select-RecordingFolder.

# --- Modern Explorer-style folder picker (Vista IFileOpenDialog) ---
$csharp = @'
using System;
using System.Runtime.InteropServices;

public static class ModernFolderPicker
{
    [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
    private class FileOpenDialogRCW { }

    [ComImport, Guid("d57c7288-d4ad-4768-be02-9d969532d960"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IFileOpenDialog
    {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
        void SetFileTypeIndex(uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise(IntPtr pfde, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOptions(uint fos);
        void GetOptions(out uint pfos);
        void SetDefaultFolder(IShellItem psi);
        void SetFolder(IShellItem psi);
        void GetFolder(out IShellItem ppsi);
        void GetCurrentSelection(out IShellItem ppsi);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult(out IShellItem ppsi);
        void AddPlace(IShellItem psi, int alignment);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close([MarshalAs(UnmanagedType.Error)] int hr);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr pFilter);
        void GetResults(out IntPtr ppenum);
        void GetSelectedItems(out IntPtr ppsai);
    }

    [ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellItem
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void SHCreateItemFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath, IntPtr pbc,
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        [MarshalAs(UnmanagedType.Interface)] out IShellItem ppv);

    private const uint FOS_NOCHANGEDIR     = 0x00000008;
    private const uint FOS_PICKFOLDERS     = 0x00000020;
    private const uint FOS_FORCEFILESYSTEM = 0x00000040;
    private const uint SIGDN_FILESYSPATH   = 0x80058000;

    public static string Pick(string title, string startPath)
    {
        var dlg = (IFileOpenDialog)(new FileOpenDialogRCW());
        uint opts;
        dlg.GetOptions(out opts);
        dlg.SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR);
        if (!string.IsNullOrEmpty(title)) { dlg.SetTitle(title); }
        if (!string.IsNullOrEmpty(startPath))
        {
            try
            {
                IShellItem start;
                SHCreateItemFromParsingName(startPath, IntPtr.Zero, typeof(IShellItem).GUID, out start);
                dlg.SetFolder(start);
            }
            catch { }
        }
        if (dlg.Show(IntPtr.Zero) != 0) { return null; }   // user cancelled
        IShellItem item;
        dlg.GetResult(out item);
        string path;
        item.GetDisplayName(SIGDN_FILESYSPATH, out path);
        return path;
    }
}
'@

function Select-RecordingFolder {
    # Open in sessions\ next to the scripts; fall back to where you last picked
    $memo = Join-Path $env:LOCALAPPDATA 'fwxxl_last_folder.txt'
    $start = Join-Path $PSScriptRoot 'sessions'
    if (-not (Test-Path $start)) { $start = '' }
    if (-not $start -and (Test-Path $memo)) {
        $saved = (Get-Content $memo -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($saved -and (Test-Path $saved)) { $start = $saved }
    }

    $picked = $null
    try {
        if (-not ('ModernFolderPicker' -as [type])) {
            Add-Type -TypeDefinition $script:csharp -ErrorAction Stop
        }
        $picked = [ModernFolderPicker]::Pick('Pick a folder with recordings', $start)
    }
    catch {
        # Fallback: classic tree picker, if the COM dialog is unavailable
        Add-Type -AssemblyName System.Windows.Forms
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = 'Pick a folder with recordings'
        if ($start) { $d.SelectedPath = $start }
        if ($d.ShowDialog() -eq 'OK') { $picked = $d.SelectedPath }
    }

    if ($picked) { Set-Content -Path $memo -Value $picked -Encoding utf8 }
    return $picked
}
