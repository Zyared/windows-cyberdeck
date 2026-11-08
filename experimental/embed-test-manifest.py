import ctypes,pathlib
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.BeginUpdateResourceW.argtypes=[ctypes.c_wchar_p,ctypes.c_int];k.BeginUpdateResourceW.restype=ctypes.c_void_p
k.UpdateResourceW.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_ushort,ctypes.c_void_p,ctypes.c_uint];k.UpdateResourceW.restype=ctypes.c_int
k.EndUpdateResourceW.argtypes=[ctypes.c_void_p,ctypes.c_int];k.EndUpdateResourceW.restype=ctypes.c_int
p=pathlib.Path(__file__).resolve().parent / 'build' / 'test-shutdown-visuals.exe';b=p.with_name('test-xaml.manifest').read_bytes();h=k.BeginUpdateResourceW(str(p),False)
if not h:raise ctypes.WinError(ctypes.get_last_error())
if not k.UpdateResourceW(h,24,1,1033,b,len(b)):raise ctypes.WinError(ctypes.get_last_error())
if not k.EndUpdateResourceW(h,False):raise ctypes.WinError(ctypes.get_last_error())
