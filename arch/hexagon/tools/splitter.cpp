#include <elf.h>
#include <stdio.h>
#include <stdlib.h>

#include <vector>
using namespace std;

int main(int argc, char** argv){
	vector<Elf32_Phdr*> psegs;

	FILE* f = fopen("vmlinux","r");
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

	Elf32_Ehdr *hdr = (Elf32_Ehdr*)buf;
	if(buf[0] != 0x7F || buf[1] != 'E' || buf[2] != 'L' || buf[3] != 'F'){
		printf("Bad magic\n");
		return 0;
	}

	printf("Entry 0x%8.8X, Ph %d, Sh %d\n", hdr->e_entry, hdr->e_phnum, hdr->e_shnum);

	int i;
	for(i=0; i < hdr->e_phnum; i++){
		Elf32_Phdr *phdr = (Elf32_Phdr*)&buf[hdr->e_phoff + hdr->e_phentsize * i];
		printf("Phdr VA: 0x%8.8X PA: 0x%8.8X\n", phdr->p_vaddr, phdr->p_paddr);
		//Save the segments we like
		if(phdr->p_paddr == 0x8DA00000){
			psegs.push_back(phdr);
		}
	}
	for(i=0; i < hdr->e_shnum; i++){
		//We like don't actually care about these
	}

	//Write out the binary segments
	for(i=0; i < psegs.size(); i++){
		char fname[32];
		sprintf(fname,"q6.b%2.2d",i);
		FILE* fbin = fopen(fname,"w");
		Elf32_Phdr *phdr = psegs[i];
		fwrite(buf + phdr->p_offset,1,phdr->p_memsz,fbin);
		fclose(fbin);
	}

	//Write out the mdt
	FILE *fmdt = fopen("q6.mdt","w");
	//Clear segment bs
	hdr->e_shnum = 0;
	hdr->e_shentsize = 0;
	hdr->e_shoff = 0;
	hdr->e_shstrndx = SHN_UNDEF;

	hdr->e_phnum = psegs.size();
	hdr->e_phoff = sizeof(*hdr);
	fwrite(hdr,1,sizeof(*hdr),fmdt);

	unsigned long offset = 0x1000;
	for(i=0; i < psegs.size(); i++){
		Elf32_Phdr *phdr = psegs[i];
		phdr->p_offset = offset;
		offset += phdr->p_memsz;
		if(offset%0x1000)
			offset += 0x1000 - offset%0x1000;
		fwrite(phdr,1,sizeof(*phdr),fmdt);
	}

	fclose(fmdt);
	return 0;
}
