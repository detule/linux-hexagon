// Cotulla: based on original jonpry's builder.cpp
//
#include <elf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


typedef unsigned long u32;


#define BOOTPARAM_SIGN		0x50423651	//'Q6BP'

#define ENTRY_OFFSET 0x20000
#define INITRD_OFFSET 0xb00000 //12MB
#define RAM_SIZE	(24 << 20)	// 24 Mb


int main(int argc, char** argv){

	if(argc!=1){
		printf("Usage builder\n");
		return 0;
	}

	char* bufInitrd;
	char* bufKernel;	
	unsigned phys=0x10000000;
	printf("Using phys offset: 0x%08X\n", phys);

	//Deal with initrd first
	FILE* f = fopen("initrd.gz","r");
	if(!f){
		printf("Couldn't open initrd file\n");
		return 0;
	}

	fseek(f, 0L, SEEK_END);
	long initrd_size = ftell(f);
	fseek(f, 0L, SEEK_SET);	
	
	bufInitrd = (char*)malloc(initrd_size);
	fread(bufInitrd, sizeof(char), initrd_size, f);
	fclose(f);



	//Load the kernel
	f = fopen("../linux-hexagon/arch/hexagon/boot/qImage","r");
	if(!f){
		printf("Couldn't open qImage file\n");
		return 0;
	}

	fseek(f, 0L, SEEK_END);
	long kernel_size = ftell(f);
	fseek(f, 0L, SEEK_SET);	
	
	bufKernel = (char*)malloc(kernel_size);
	fread(bufKernel, sizeof(char), kernel_size, f);
	fclose(f);

	//Update kernel tags
	((unsigned int*)bufKernel)[0] = BOOTPARAM_SIGN;
	((unsigned int*)bufKernel)[1] = phys + INITRD_OFFSET;
	((unsigned int*)bufKernel)[2] = initrd_size;



	

	///////////////////////////////
	// LAYOUT:
	//
	// 1. kernel (qImage) 
	// 2. ram gap1 (initrd_start - kernel_end)
	// 3. initrd (initrd.gz)
	// 4. ram gap2 (ram_end - initrd_start)
	//
	u32 ram_start = phys;
	u32 initrd_start = ram_start + INITRD_OFFSET;
	u32 initrd_end = initrd_start + initrd_size;
	u32 ram_end = ram_start + RAM_SIZE;

	unsigned long foffset = 0x1000;
	Elf32_Ehdr ehdr = {0};
	Elf32_Phdr phdrs[4];


	char* chdr = (char*)&ehdr;	
	chdr[0] = 0x7F;
	chdr[1] = 'E';
	chdr[2] = 'L';
	chdr[3] = 'F';
	chdr[4] = 1;
	chdr[5] = 1;
	chdr[6] = 1;


	ehdr.e_type = ET_EXEC;
	ehdr.e_machine = 164; //Hexagon
	ehdr.e_version = EV_CURRENT;
	ehdr.e_entry = phys + ENTRY_OFFSET;	// 0x1002 0000
	ehdr.e_phoff = sizeof(ehdr);
	ehdr.e_shoff = 0;
	ehdr.e_flags = 1;
	ehdr.e_ehsize = sizeof(ehdr);
	ehdr.e_phentsize = sizeof(Elf32_Phdr);
	ehdr.e_phnum = 2;
	ehdr.e_shentsize = 0;
	ehdr.e_shnum = 0;	
	ehdr.e_shstrndx = SHN_UNDEF;

	

	phdrs[0].p_type = PT_LOAD;
	phdrs[0].p_offset = 0x1000;
	phdrs[0].p_vaddr = ram_start;
	phdrs[0].p_paddr = ram_start;
	phdrs[0].p_filesz = kernel_size;
	phdrs[0].p_memsz = (initrd_start - ram_start);
	phdrs[0].p_flags = PF_X | PF_R | PF_W;
	phdrs[0].p_align = 0;


	u32 voffset = kernel_size;
	if (voffset % 0x1000) voffset += 0x1000 - voffset%0x1000;

	phdrs[1].p_type = PT_LOAD;
	phdrs[1].p_offset = 0x1000 + voffset;
	phdrs[1].p_vaddr = ram_start + INITRD_OFFSET;
	phdrs[1].p_paddr = ram_start + INITRD_OFFSET;
	phdrs[1].p_filesz = initrd_size;
	phdrs[1].p_memsz = (ram_end - initrd_start);
	phdrs[1].p_flags = PF_X | PF_R | PF_W;
	phdrs[1].p_align = 0;


	// finally write an output file 
	//

	FILE* fbin = fopen("Q6.elf", "w");
	if (!fbin) 
	{
		printf("can not create output file!\n");
		return -1;
	}

	// Write header
	fwrite(&ehdr, 1, sizeof(Elf32_Ehdr), fbin);	
	fwrite(&phdrs[0], 1, 2 * sizeof(Elf32_Phdr), fbin);	


	// Write kernel
	fseek(fbin, phdrs[0].p_offset, SEEK_SET);
	fwrite(bufKernel,1,kernel_size,fbin);

	// Write initrd
	fseek(fbin, phdrs[1].p_offset, SEEK_SET);
	fwrite(bufInitrd,1,initrd_size,fbin);

	fclose(fbin);

	printf("Done\n");
	return 0;
}
