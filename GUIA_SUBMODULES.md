# Guia de Trabalho com Git Submodules

Este repositório (`escritorio-adv`) usa **Git submodules** para referenciar os repositórios `frontend` e `backend`. Entender como isso funciona é essencial para não perder trabalho ou quebrar os ponteiros.

---

## Como funciona

O repo pai **não armazena o código** do frontend e backend — ele armazena apenas um **ponteiro** (hash de commit) que diz "o frontend está no commit X".

```
escritorio-adv/
  backend  →  aponta para commit abc123 no repo backend
  frontend →  aponta para commit 258c19 no repo frontend
```

Quando você roda `git submodule update`, o Git entra em cada pasta e faz checkout exatamente naquele commit. Por isso, ao entrar em `frontend/` você pode estar em **detached HEAD** (sem branch nenhuma) — isso é normal, mas exige atenção.

---

## Fluxo correto de trabalho

### Regra de ouro: branches espelhadas

Cada feature deve ter uma branch com o **mesmo nome** nos três repos:

```
escritorio-adv   →  branch: minha-feature
  backend/       →  branch: minha-feature
  frontend/      →  branch: minha-feature
```

---

### 1. Começando uma feature

```bash
# No repo pai
git checkout -b minha-feature

# Entrar no frontend e criar branch equivalente
cd frontend
git checkout -b minha-feature
cd ..

# Idem no backend
cd backend
git checkout -b minha-feature
cd ..
```

---

### 2. Desenvolvendo

Trabalhe normalmente dentro de `frontend/` e `backend/` como se fossem repos independentes — porque são.

```bash
cd frontend
# ... edita arquivos ...
git add .
git commit -m "feat: minha alteração"
cd ..
```

> **Importante:** commitar dentro do submodule não atualiza o ponteiro no repo pai automaticamente. Isso é feito manualmente na etapa 4.

---

### 3. Subindo os submodules (antes do repo pai)

Quando a feature estiver pronta, suba e abra PRs nos repos dos submodules **primeiro**:

```bash
# Frontend
cd frontend
git push origin minha-feature
# → Abrir PR de minha-feature → main no repo frontend e aguardar merge
cd ..

# Backend
cd backend
git push origin minha-feature
# → Abrir PR de minha-feature → main no repo backend e aguardar merge
cd ..
```

---

### 4. Atualizando os ponteiros no repo pai

Somente **após os PRs serem aceitos** nos submodules, atualize os ponteiros no `escritorio-adv`:

```bash
# Atualizar os submodules para o novo commit de main
cd frontend
git checkout main
git pull
cd ..

cd backend
git checkout main
git pull
cd ..

# Commitar o avanço dos ponteiros
git add frontend backend
git commit -m "chore: atualiza ponteiros após merge da minha-feature"
git push origin minha-feature
# → Abrir PR no escritorio-adv
```

---

## Ordem resumida

```
1. Cria branch com mesmo nome nos 3 repos
2. Desenvolve nos submodules (frontend, backend)
3. PRs e merges nas mains dos submodules
4. Atualiza os ponteiros no repo pai (escritorio-adv)
5. PR no repo pai apontando para os novos commits de main
```

> O repo pai serve para "fotografar" qual versão do front e do back funcionam juntos. Nunca commitar código de feature direto nele — só ponteiros.

---

## Comandos úteis

### Clonar o repo com submodules pela primeira vez
```bash
git clone --recurse-submodules <url-do-repo>
```

### Inicializar submodules após clonar sem a flag acima
```bash
git submodule update --init --recursive
```

### Ver o estado atual dos submodules
```bash
git submodule status
```

### Colocar todos os submodules em uma branch (evitar detached HEAD)
```bash
git submodule foreach 'git checkout main || true'
```

### Atualizar todos os submodules para o commit mais recente da branch atual
```bash
git submodule update --remote
```
