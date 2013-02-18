#include <elf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <vector>
using namespace std;

#define PHYS 0x47000000

int main(int argc, char** argv){
	vector<Elf32_Phdr*> psegs;

	FILE* f = fopen("arch/hexagon/boot/qImage","r");
	if(!f){
		printf("Couldn't open file\n");
		return 0;
	}

	fseek(f, 0L, SEEK_END);
	long numbytes = ftell(f);
	fseek(f, 0L, SEEK_SET);	
	
	char* buf = (char*)malloc(numbytes);
	fread(buf, sizeof(char), numbytes, f);
	fclose(f);

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
	hdr->e_entry = PHYS;
	hdr->e_phoff = sizeof(*hdr);
	hdr->e_shoff = 0;
	hdr->e_flags = 0;
	hdr->e_ehsize = sizeof(*hdr);
	hdr->e_phentsize = sizeof(Elf32_Phdr);
	hdr->e_phnum = 1;
	hdr->e_shentsize = 0;
	hdr->e_shnum = 0;	
	hdr->e_shstrndx = SHN_UNDEF;


	//Write out the binary segments
	char fname[32];
	sprintf(fname,"q6.b00");
	FILE* fbin = fopen(fname,"w");
	fwrite(buf,1,numbytes,fbin);
	fclose(fbin);

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

	fclose(fmdt);
	return 0;
}
