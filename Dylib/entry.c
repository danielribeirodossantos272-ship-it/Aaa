// Ponto de entrada nativo da dylib: o dyld executa este constructor quando a dylib é carregada.
// Swift não tem __attribute__((constructor)), então este arquivo só chama a função Swift exportada.
extern void flexreplica_start(void);

__attribute__((constructor))
static void flexreplica_entry(void) {
    flexreplica_start();
}
