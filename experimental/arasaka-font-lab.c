// Exact-build font experiment. Default build is restricted to EDK II / WinRE.
// No kernel/DSE/PatchGuard patches, disk writes, EFI variable changes, or
// runtime-service hooks. Host build is separately pinned by generated targets.
// Uses EDK II headers (BSD-2-Clause-Patent). Boot-application ABI researched
// against Mattiwatti/EfiGuard; this implementation is restricted to exact PEs.
#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/DevicePath.h>
#include <Protocol/SimpleFileSystem.h>
#include <IndustryStandard/PeImage.h>
#include "font-lab-targets.h"
#ifndef LAB_PATCH_ENABLED
#define LAB_PATCH_ENABLED 1
#endif
#ifndef ARASAKA_HOST_BUILD
#define ARASAKA_HOST_BUILD 0
#endif
#ifndef ARASAKA_HACKBGRT_CHAIN
#define ARASAKA_HACKBGRT_CHAIN 0
#endif
// shim requires SBAT metadata even when the exact binary hash is enrolled.
__attribute__((section(".sbat"),used)) const char arasaka_sbat[]=
    "sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md\n"
    "arasaka-font,1,Zyared,arasaka-font,1,https://github.com/Zyared/windows-cyberdeck\n";

static EFI_SYSTEM_TABLE *st;
static UINT8 *transfer;
static UINT8 saved[12];
static EFI_GUID loaded_guid = EFI_LOADED_IMAGE_PROTOCOL_GUID;
static EFI_GUID path_guid = EFI_DEVICE_PATH_PROTOCOL_GUID;
#if !ARASAKA_HOST_BUILD
static EFI_GUID fs_guid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
#endif
static const CHAR16 spinner_path[]=L"\\boot\\fonts\\segoe_slboot.ttf";
static EFI_IMAGE_LOAD original_load;

static void copy(void *to, const void *from, UINTN n) {
    UINT8 *d=to; const UINT8 *s=from;
    for (UINTN i=0;i<n;i++) d[i]=s[i];
}
static BOOLEAN equal(const void *a, const void *b, UINTN n) {
    const UINT8 *x=a,*y=b;
    for(UINTN i=0;i<n;i++) if(x[i]!=y[i]) return FALSE;
    return TRUE;
}
static void trace(const char *s) {
#if ARASAKA_HOST_BUILD
    (void)s; // Port E9 is a QEMU diagnostic device, not a host logging API.
#else
    while(*s) { __asm__ volatile("outb %0, $0xe9" : : "a"((UINT8)*s++)); }
#endif
}
static void trace_status(UINTN value) {
    static const char hex[]="0123456789abcdef";
    char text[19];text[0]='0';text[1]='x';text[18]=0;
    for(UINTN i=0;i<16;i++)text[2+i]=hex[(value>>((15-i)*4))&15];
    trace(text);trace("\n");
}
static void write_code(void *to,const void *from,UINTN n) {
    UINTN cr0;
    __asm__ volatile("mov %%cr0, %0":"=r"(cr0));
    UINTN writable=cr0 & ~((UINTN)1<<16);
    __asm__ volatile("mov %0, %%cr0"::"r"(writable):"memory");
    volatile UINT8 *d=to; const UINT8 *s=from;
    for(UINTN i=0;i<n;i++) d[i]=s[i];
    __asm__ volatile("mov %0, %%cr0"::"r"(cr0):"memory");
}
static BOOLEAN target_matches(void *image, UINTN supplied_size, const Target *t) {
    if(!image || supplied_size<sizeof(EFI_IMAGE_NT_HEADERS64)+sizeof(EFI_IMAGE_DOS_HEADER)) return FALSE;
    UINT8 *b=image; EFI_IMAGE_DOS_HEADER *dos=image;
    if(dos->e_magic!=EFI_IMAGE_DOS_SIGNATURE || dos->e_lfanew<0 ||
       (UINTN)dos->e_lfanew>supplied_size-sizeof(EFI_IMAGE_NT_HEADERS64)) return FALSE;
    EFI_IMAGE_NT_HEADERS64 *nt=(void*)(b+dos->e_lfanew);
    if(nt->Signature!=EFI_IMAGE_NT_SIGNATURE ||
       nt->FileHeader.Machine!=IMAGE_FILE_MACHINE_X64 ||
       nt->OptionalHeader.Magic!=EFI_IMAGE_NT_OPTIONAL_HDR64_MAGIC ||
       nt->FileHeader.TimeDateStamp!=t->timestamp ||
       nt->OptionalHeader.SizeOfImage!=t->size ||
       nt->OptionalHeader.CheckSum!=t->checksum || t->size>supplied_size ||
       t->font_rva>t->size-32 || t->path_rva>t->size-sizeof(spinner_path)) return FALSE;
    return equal(b+t->font_rva,t->font_bytes,32) &&
           equal(b+t->path_rva,spinner_path,sizeof(spinner_path));
}
static void accept_lab_font(void *image,const Target *t) {
    static const UINT8 success[]={0x31,0xc0,0xc3}; // return STATUS_SUCCESS
    write_code((UINT8*)image+t->font_rva,success,sizeof(success));
    static const CHAR16 own_path[]=L"\\aras\\fonts\\segoe_slboot.ttf";
    write_code((UINT8*)image+t->path_rva,own_path,sizeof(own_path));
}
typedef UINTN (EFIAPI *StartApplication)(void*,void*,UINT32,UINT32,void*);
static UINTN EFIAPI start_hook(void *entry,void *image,UINT32 size,UINT32 option,void *ret) {
    // Remove the one-shot hook before calling any Windows function.
    write_code(transfer,saved,sizeof(saved));
    if(target_matches(image,size,&winload_target)) {
        accept_lab_font(image,&winload_target);
        trace("ARASAKA_LAB: exact winload matched; font verifier and isolated font path patched\n");
    } else {
        trace("ARASAKA_LAB: unexpected next image; no winload changes\n");
    }
    return ((StartApplication)transfer)(entry,image,size,option,ret);
}

static void patch_bootmgr(EFI_HANDLE child) {
    EFI_LOADED_IMAGE_PROTOCOL *loaded=NULL;
    EFI_STATUS status=st->BootServices->HandleProtocol(child,&loaded_guid,(void**)&loaded);
    if(EFI_ERROR(status) || !target_matches(loaded->ImageBase,loaded->ImageSize,&bootmgr_target)) {
        trace("ARASAKA_LAB: Boot Manager mismatch; continuing without animation patches\n");
        return;
    }
    transfer=(UINT8*)loaded->ImageBase+TRANSFER_RVA;
    if(TRANSFER_RVA>bootmgr_target.size-32 || !equal(transfer,transfer_bytes,32)) return;
    copy(saved,transfer,sizeof(saved));
    UINT8 jump[12]={0x48,0xb8,0,0,0,0,0,0,0,0,0xff,0xe0};
    UINTN destination=(UINTN)&start_hook;
    copy(jump+2,&destination,sizeof(destination));
    if(LAB_PATCH_ENABLED) {
        accept_lab_font(loaded->ImageBase,&bootmgr_target);
        write_code(transfer,jump,sizeof(jump));
        trace("ARASAKA_LAB: exact Boot Manager matched; font verifier and one-shot transfer hook set\n");
    } else trace("ARASAKA_LAB: control, no boot code changes\n");
}

#if ARASAKA_HACKBGRT_CHAIN
static void restore_load(void) {
    st->BootServices->LoadImage=original_load;
    st->BootServices->Hdr.CRC32=0;
    st->BootServices->CalculateCrc32(st->BootServices,st->BootServices->Hdr.HeaderSize,
                                    &st->BootServices->Hdr.CRC32);
}
static EFI_STATUS EFIAPI load_once(BOOLEAN policy,EFI_HANDLE parent,
    EFI_DEVICE_PATH_PROTOCOL *path,VOID *buffer,UINTN size,EFI_HANDLE *child) {
    // Restore the firmware API before invoking it. Only HackBGRT's first load
    // is observed; signatures remain the responsibility of the original API.
    restore_load();
    EFI_STATUS status=original_load(policy,parent,path,buffer,size,child);
    if(!EFI_ERROR(status)) patch_bootmgr(*child);
    return status;
}
#endif

EFI_STATUS EFIAPI EfiMain(EFI_HANDLE self,EFI_SYSTEM_TABLE *system) {
    st=system;
#if !ARASAKA_HOST_BUILD
    // Prevent this experimental binary from being used on the physical laptop.
    static const CHAR16 lab_vendor[]=L"EDK II";
    if(!st->FirmwareVendor || !equal(st->FirmwareVendor,lab_vendor,sizeof(lab_vendor)))
        return EFI_UNSUPPORTED;
#endif
    trace("ARASAKA_LAB: entering isolated EFI font experiment\n");
    EFI_GUID global_guid={0x8be4df61,0x93ca,0x11d2,{0xaa,0x0d,0x00,0xe0,0x98,0x03,0x2b,0x8c}};
    UINT8 secure=0; UINTN secure_size=1;
    EFI_STATUS secure_status=st->RuntimeServices->GetVariable(L"SecureBoot",&global_guid,NULL,&secure_size,&secure);
    if(!EFI_ERROR(secure_status)) trace(secure ? "ARASAKA_LAB: SecureBoot=1\n" : "ARASAKA_LAB: SecureBoot=0\n");
    EFI_DEVICE_PATH_PROTOCOL *device=NULL;
    // Lab: exactly one WIM volume. Host: the volume this EFI app was loaded from.
    // Never scan or guess a physical disk identifier in the host build.
    EFI_HANDLE volume=NULL;
    EFI_STATUS status;
#if ARASAKA_HOST_BUILD
    EFI_LOADED_IMAGE_PROTOCOL *own_image=NULL;
    status=st->BootServices->HandleProtocol(self,&loaded_guid,(void**)&own_image);
    if(EFI_ERROR(status)) return status;
    volume=own_image->DeviceHandle;
#else
    EFI_HANDLE *volumes=NULL; UINTN count=0,matches=0;
    status=st->BootServices->LocateHandleBuffer(ByProtocol,&fs_guid,NULL,&count,&volumes);
    if(EFI_ERROR(status)) return status;
    for(UINTN i=0;i<count;i++) {
        EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs=NULL; EFI_FILE_PROTOCOL *root=NULL,*wim=NULL;
        status=st->BootServices->HandleProtocol(volumes[i],&fs_guid,(void**)&fs);
        if(EFI_ERROR(status)) continue;
        status=fs->OpenVolume(fs,&root);
        if(EFI_ERROR(status)) continue;
        status=root->Open(root,&wim,L"\\sources\\boot.wim",EFI_FILE_MODE_READ,0);
        if(!EFI_ERROR(status)) {volume=volumes[i];matches++;wim->Close(wim);}
        root->Close(root);
    }
    st->BootServices->FreePool(volumes);
    if(matches!=1){trace("ARASAKA_LAB: expected one WIM volume\n");return EFI_NOT_FOUND;}
#endif
    status=st->BootServices->HandleProtocol(volume,&path_guid,(void**)&device);
    if(EFI_ERROR(status)) return status;
    UINTN prefix=0;
    while(prefix<65536) {
        EFI_DEVICE_PATH_PROTOCOL *node=(void*)((UINT8*)device+prefix);
        if(node->Type==0x7f) break;
        UINTN size=node->Length[0]+((UINTN)node->Length[1]<<8);
        if(size<4 || prefix+size>=65536) return EFI_COMPROMISED_DATA;
        prefix+=size;
    }
    if(prefix>=65536) return EFI_COMPROMISED_DATA;
#if ARASAKA_HACKBGRT_CHAIN
    static const CHAR16 name[]=L"\\EFI\\ArasakaAnim\\hackbgrt.efi";
#else
    static const CHAR16 name[]=L"\\EFI\\Microsoft\\Boot\\bootmgfw.efi";
#endif
    UINTN file_size=4+sizeof(name),total=prefix+file_size+4;
    UINT8 *path=NULL;
    status=st->BootServices->AllocatePool(EfiBootServicesData,total,(void**)&path);
    if(EFI_ERROR(status)) return status;
    copy(path,device,prefix);
    path[prefix]=4;path[prefix+1]=4;
    path[prefix+2]=(UINT8)file_size;path[prefix+3]=(UINT8)(file_size>>8);
    copy(path+prefix+4,name,sizeof(name));
    path[total-4]=0x7f;path[total-3]=0xff;path[total-2]=4;path[total-1]=0;
    EFI_HANDLE child=NULL;
    status=st->BootServices->LoadImage(FALSE,self,(void*)path,NULL,0,&child);
    st->BootServices->FreePool(path);
    if(EFI_ERROR(status)){trace("ARASAKA_LAB: LoadImage failed\n");return status;}
#if ARASAKA_HACKBGRT_CHAIN
    original_load=st->BootServices->LoadImage;
    st->BootServices->LoadImage=load_once;
    st->BootServices->Hdr.CRC32=0;
    st->BootServices->CalculateCrc32(st->BootServices,st->BootServices->Hdr.HeaderSize,
                                    &st->BootServices->Hdr.CRC32);
#else
    (void)original_load;
    patch_bootmgr(child);
#endif
    status=st->BootServices->StartImage(child,NULL,NULL);
#if ARASAKA_HACKBGRT_CHAIN
    restore_load();
#endif
    trace("ARASAKA_LAB: Windows boot application returned\n");
    trace_status(status);
    st->BootServices->UnloadImage(child);
    return status;
}
