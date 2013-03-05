#include <elf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define BOOTPARAM_SIGN		0x50423651	//'Q6BP'

#define PHYS phys//0x47000000
#define ENTRY_OFFSET 0x20000
#define INITRD_OFFSET 0xb00000 //12MB

int main(int argc, char** argv){
	if(argc!=2){
		printf("Usage splitter PHYS_OFFSET\n");
		return 0;
	}

	unsigned phys=0;
	sscanf(argv[1],"%X",&phys);
	printf("Using phys offset: 0x%08X\n", phys);

	//Deal with initrd first
	FILE* f = fopen("initrd","r");
	if(!f){
		printf("Couldn't open file\n");
		return 0;
	}

	fseek(f, 0L, SEEK_END);
	long initrd_numbytes = ftell(f);
	fseek(f, 0L, SEEK_SET);	
	
	char* buf = (char*)malloc(initrd_numbytes);
	fread(buf, sizeof(char), initrd_numbytes, f);
	fclose(f);

	//Write out the initrd
	char fname[32];
	sprintf(fname,"q6.b01");
	FILE* fbin = fopen(fname,"w");
	fwrite(buf,1,initrd_numbytes,fbin);
	fclose(fbin);


	//Load the kernel
	f = fopen("arch/hexagon/boot/qImage","r");
	if(!f){
		printf("Couldn't open file\n");
		return 0;
	}

	fseek(f, 0L, SEEK_END);
	long numbytes = ftell(f);
	fseek(f, 0L, SEEK_SET);	
	
	buf = (char*)malloc(numbytes);
	fread(buf, sizeof(char), numbytes, f);
	fclose(f);

	//Update kernel tags
	((unsigned int*)buf)[0] = BOOTPARAM_SIGN;
	((unsigned int*)buf)[1] = PHYS + INITRD_OFFSET;
	((unsigned int*)buf)[2] = initrd_numbytes;
	
	//Write out the kernel binary segment

	sprintf(fname,"q6.b00");
	fbin = fopen(fname,"w");
	fwrite(buf,1,numbytes,fbin);
	fclose(fbin);

	Elf32_Ehdr *hdr = (Elf32_Ehdr*)malloc(sizeof(Elf32_Ehdr));
	memset(hdr,0,sizeof(Elf32_Ehdr));
	char* chdr = (char*)hdr;	
	chdr[0] = 0x7F;
	chdr[1] = 'E';
	chdr[2] = 'L';
	chdr[3] = 'F';

	hdr->e_type = ET_EXEC;
	hdr->e_machine = 164; //Hexagon
	hdr->e_version = EV_CURRENT;
	hdr->e_entry = PHYS + ENTRY_OFFSET;
	hdr->e_phoff = sizeof(*hdr);
	hdr->e_shoff = 0;
	hdr->e_flags = 0;
	hdr->e_ehsize = sizeof(*hdr);
	hdr->e_phentsize = sizeof(Elf32_Phdr);
	hdr->e_phnum = 2;
	hdr->e_shentsize = 0;
	hdr->e_shnum = 0;	
	hdr->e_shstrndx = SHN_UNDEF;


	//Write out the mdt
	FILE *fmdt = fopen("q6.mdt","w");
	fwrite(hdr,1,sizeof(*hdr),fmdt);
	unsigned long offset = 0x1000;
	Elf32_Phdr *phdr = (Elf32_Phdr*)malloc(sizeof(Elf32_Phdr));

	phdr->p_type = PT_LOAD;
	phdr->p_offset = 0x1000;
	phdr->p_vaddr = PHYS;
	phdr->p_paddr = PHYS;
	phdr->p_filesz = numbytes;
	phdr->p_memsz = numbytes;
	phdr->p_flags = PF_X | PF_R | PF_W;
	phdr->p_align = 0;


	fwrite(phdr,1,sizeof(*phdr),fmdt);

	unsigned voffset = numbytes;
	if(voffset%0x1000)
		voffset += 0x1000 - voffset%0x1000;

	phdr->p_type = PT_LOAD;
	phdr->p_offset = 0x1000 + voffset;;
	phdr->p_vaddr = PHYS+INITRD_OFFSET;
	phdr->p_paddr = PHYS+INITRD_OFFSET;
	phdr->p_filesz = initrd_numbytes;
	phdr->p_memsz = initrd_numbytes;
	phdr->p_flags = PF_X | PF_R | PF_W;
	phdr->p_align = 0;


	fwrite(phdr,1,sizeof(*phdr),fmdt);


	fclose(fmdt);
	return 0;
}
