# hackathon-magalu-2024

```sh
exportenv() {
    export $(grep -v '^#' .env | xargs)
}
```

## Poréns

**Precisa** criar um security group ANTES de sair criando, o lb vai usar (tb precisa configurar, expor 27017 e 22 pelo console `as of Oct-2024`). Pegar o id da security-group na CLI com:

```sh
mgc network security-groups list
```

.. e colocar no [variables.tf](/mongodb/variables.tf)
