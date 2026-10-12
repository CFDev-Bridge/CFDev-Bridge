<div align="center">

# CFDev-Bridge

### Software · Data · Artificial Intelligence · Innovation

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0f172a,100:2563eb&height=180&section=header&text=CFDev-Bridge&fontSize=48&fontColor=ffffff&animation=fadeIn&fontAlignY=38&desc=Building%20technology%20that%20connects%20ideas%20and%20solutions&descAlignY=60&descSize=16" width="100%"/>

</div>

---

<div align="center">

### 🚀 Technology • Engineering • Data

We create software solutions focused on **development, data, automation and artificial intelligence**.

</div>

---

## 🧩 What we do

<table>
<tr>
<td width="50%">

### 💻 Software Development

Design and development of modern software solutions, web applications and enterprise systems.

</td>
<td width="50%">

### 📊 Data & Analytics

Data processing, analysis, visualization and solutions designed to transform information into value.

</td>
</tr>

<tr>
<td width="50%">

### 🤖 Artificial Intelligence

Exploration and development of solutions based on artificial intelligence, machine learning and intelligent systems.

</td>
<td width="50%">

### ⚙️ Automation & Integration

Integration between systems, APIs, databases and automated processes.

</td>
</tr>
</table>

---

## 🛠️ Technology Stack

### Languages

<p>
<img src="https://skillicons.dev/icons?i=java,python,js,ts" />
</p>

### Web Development

<p>
<img src="https://skillicons.dev/icons?i=angular,react,html,css" />
</p>

### Data & Databases

<p>
<img src="https://skillicons.dev/icons?i=oracle,postgres,mysql,mongodb" />
</p>

### Tools & Infrastructure

<p>
<img src="https://skillicons.dev/icons?i=git,github,docker,linux,vscode" />
</p>

---

## 📂 Projects

Our repositories contain projects, experiments and solutions across different areas of technology.

<div align="center">

| Area | Focus |
|---|---|
| 💻 Software | Web applications and enterprise solutions |
| 📊 Data | Data processing, analytics and visualization |
| 🤖 AI | Artificial intelligence and intelligent systems |
| 🔌 APIs | Services, integrations and automation |
| 🗄️ Databases | Data architecture and management |
| 🧪 Research | Technology experimentation and prototypes |

</div>

---

## 🌐 Engineering Approach

```text
                    ┌─────────────────────┐
                    │      CFDev-Bridge   │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
     SOFTWARE                DATA                  AI
          │                    │                    │
     ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
     │         │         │         │         │         │
    WEB      APIs      ANALYTICS  DB      ML      AUTOMATION
     │         │         │         │         │         │
     └─────────┴─────────┴─────────┴─────────┴─────────┘
                               │
                               ▼
                         🚀 SOLUTIONS

---

## 🧠 Claude Skills installer

`install-claude-skills.sh` instala [Agent Skills](https://github.com/anthropics/skills) en Claude Code, a nivel de usuario (`~/.claude/skills`) o de proyecto (`./.claude/skills`).

```bash
chmod +x install-claude-skills.sh

./install-claude-skills.sh --list                      # ver skills disponibles
./install-claude-skills.sh pdf docx xlsx pptx          # instalar (scope usuario)
./install-claude-skills.sh --all --scope project       # todas, en el proyecto actual
./install-claude-skills.sh --ref <commit> pdf          # fijar versión (reproducible)
./install-claude-skills.sh -s ./mis-skills -p . --all  # origen local
./install-claude-skills.sh --help                      # todas las opciones
```

Seguridad: valida nombres de skill y frontmatter (`name`/`description`) de cada `SKILL.md`, rechaza rutas con `..` y skills con enlaces simbólicos, instala de forma atómica y, con `--force`, respalda la versión previa.
