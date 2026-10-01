# dw-framework

A metadata-driven data warehouse automation framework for SQL Server, particularly useful for [Anchor Modeling](http://www.anchormodeling.com).

You describe your sources, your targets and your workflows in XML. The framework generates the SQL that loads, types, merges and schedules the data, and records what it does in a metadata model of its own. The data stays inside SQL Server, which makes this an ELT framework rather than an ETL tool: files are bulk loaded into raw tables, and generated stored procedures move the data on from there.

- [Video tutorials](https://www.youtube.com/playlist?list=PLG6-3kKEOyYlWEaEFzhcARtjqHU6zn1cH)
- [Release notes](CHANGELOG.md), newest first.

## What it generates

| You describe | In | The framework generates | Filter |
|---|---|---|---|
| A source: a flat file with its columns, types and delimiters | `sources/*.xml` | A bulk format file in `formats/`, and `sources/*.sql`: the schema, raw and typed tables, the views that split and check the rows, the bulk insert, and the procedures that move raw rows into the typed tables | `S` |
| A target: loads, each mapping a source to a target table | `targets/*.xml` | `targets/*.sql`: the loading procedures, which merge into the targets. BIML for SSIS in `biml/`, if that folder exists | `T` |
| A workflow: jobs and their steps | `workflows/*.xml` | `workflows/*.sql`: the SQL Server Agent jobs | `W` |

The generated procedures log every run to the metadata model, together with the definitions they were generated from.

## Requirements

- **Windows PowerShell 5.1 or later.** `Sisulate.ps1` runs the generator in [Jint](https://github.com/sebastienros/jint), a JavaScript interpreter that is bundled in `code/DLL/`, so nothing else has to be installed.
- **SQL Server 2008 to 2022**, with SQL Server Agent if you use workflows. The folders named `SQL Server 2005` hold variants of the scripts for that version.
- **`sqlcmd`**, only if you let the script install the generated SQL (the `<server>` argument below).
- **Rights to enable and install the CLR.** Loading a source uses small .NET functions for splitting and type checking. The generated source script installs the assembly that matches your SQL Server (`code/Utilities<year>.dll`), enables `clr enabled` if it is off, and from SQL Server 2017 adds the assembly to the trusted assemblies using the `.SHA512` file next to it.
- If your machine only runs signed PowerShell scripts, `Sign-Sisulate.ps1` creates a self-signed certificate for your machine and signs `Sisulate.ps1` with it.

## Quick start

```
.\Sisulate.ps1 <project folder> [<server>] [<filters>]
```

| Argument | Meaning |
|---|---|
| `project folder` | The folder with `sources`, `targets`, `workflows` and `Variables.BAT`. See [A project folder](#a-project-folder). |
| `server` | Optional. If given, the generated SQL files are installed on that server with `sqlcmd`: sources first, then targets, then workflows. |
| `filters` | Optional. Which parts to run: `S` sources, `T` targets, `W` workflows. The default is `STW`. |

```
.\Sisulate.ps1 .\Examples\Golf                  # generate the files only
.\Sisulate.ps1 .\Examples\Golf localhost        # generate them and install them on localhost
.\Sisulate.ps1 .\Examples\Golf localhost W      # only the workflow jobs
```

The SQL files are written next to the XML they come from, the bulk format files to `formats/` and the BIML to `biml/`, and they replace any earlier ones.

Before installing, the databases that `Variables.BAT` names (`SourceDatabase`, `TargetDatabase` and `MetaDatabase`) have to exist; the framework does not create them. The tables that the targets load into come from your Anchor model. The generated code also writes its log to the metadata model in the database that `MetaDatabase` names. Install that model by running the scripts in `metadata\` in numeric order in that database. The same scripts upgrade an existing installation: the [release notes](CHANGELOG.md) say when an upgrade needs them again. `stats\` holds an optional model and procedure for gathering statistics.

There are two complete projects in `Examples/`, each with an Anchor model (`model/`, as XML and as SQL), data to load (`data/incoming`) and all the XML:

- **Golf**: PGA golf statistics by player and date, loaded into an Anchor model.
- **Traffic**: collision data for Manhattan, which also generates BIML.

## A project folder

A project is organized into a standardized folder structure. The main `Sisulate.ps1` script is designed to look for files in specific subdirectories based on the filters (`S`, `T`, `W`) you provide. Adhering to this structure is essential for the tool to work correctly.

Based on the provided examples, here is the standard project layout:

```
<Your_Project_Folder>/
|
|-- sources/
|   |-- SourceFile1.xml
|   `-- SourceFile2.xml
|
|-- targets/
|   |-- TargetTable1.xml
|   `-- TargetTable2.xml
|
|-- workflows/
|   |-- MainWorkflow.xml
|   `-- ...
|
|-- formats/
|   |-- (This is an OUTPUT directory)
|   `-- ...
|
|-- biml/
|   |-- (This is an OUTPUT directory)
|   `-- ...
|
|-- scripts/
|   |-- HelperScript1.ps1
|   `-- ...
|
`-- Variables.BAT
```

### Folder and File Descriptions

*   **`sources/` (Input)**
    *   **Purpose:** Contains the XML definitions of your raw data sources. Each XML file typically describes a flat file or another data source, detailing its columns, data types, and delimiters.
    *   **Used by Filter:** `S`
    *   **Generates:** BCP format files in `formats/` and source-loading SQL procedures in `sources/` (e.g., `SourceFile1.sql`).

*   **`targets/` (Input)**
    *   **Purpose:** Contains the XML definitions of your destination tables in the data warehouse. These files define the table structure and, most importantly, the mapping logic from one or more sources to the target.
    *   **Used by Filter:** `T`
    *   **Generates:** Target-loading SQL procedures in `targets/` (e.g., `TargetTable1.sql`) and Business Intelligence Markup Language files in `biml/`.

*   **`workflows/` (Input)**
    *   **Purpose:** Contains the XML definitions of the orchestration logic. These files describe the sequence of tasks to be performed, which are then transformed into SQL Server Agent Jobs. This is where you define the steps of your ETL process (e.g., "Run source A load, then run target B load").
    *   **Used by Filter:** `W`
    *   **Generates:** SQL scripts in `workflows/` that create the corresponding SQL Server Agent Jobs.

*   **`formats/` (Output)**
    *   **Purpose:** This is an **output-only** directory. The Sisulator engine places the generated BCP (Bulk Copy Program) format files here. These XML-based format files are used by SQL Server to efficiently bulk-load data from flat files.
    *   **Generated from:** `sources/`

*   **`biml/` (Output)**
    *   **Purpose:** This is an **output-only** directory. The engine places the generated BIML files here. BIML is a dialect of XML used to declare business intelligence assets. These files are typically used by tools like BimlStudio to automatically generate SSIS (SQL Server Integration Services) packages.
    *   **Generated from:** `targets/`

*   **`scripts/` (Supporting Files)**
    *   **Purpose:** A conventional location for any external helper scripts (e.g., PowerShell `.ps1`, Python `.py`, command files `.cmd`) that are executed by the steps in your workflows. For example, a job step generated from `workflows/MainWorkflow.xml` might call `PowerShell %ProjectDirectory%\scripts\HelperScript1.ps1`. The Sisulator engine itself does not directly read this folder, but the generated artifacts often rely on it.

*   **`Variables.BAT` (Configuration)**
    *   **Purpose:** This is the central configuration file for the entire project. It is used to define key-value pairs that control the behavior of the transformations. Common variables include database names (`SourceDatabase`, `TargetDatabase`), server names, and file paths (`WorkDataDirectory`, `ArchiveDataDirectory`). These variables are loaded into the `VARIABLES` object and are accessible in all sisulets, allowing for environment-specific configuration without changing the core transformation logic.

## What is in this repository

| Path | What it is |
|---|---|
| `Sisulate.ps1` | The generator and installer. |
| `Sisulator4PS.js` | The Sisulator engine that `Sisulate.ps1` runs in Jint. |
| `source.directive`, `target.directive`, `workflow.directive`, `format.directive`, `biml.directive` | For each kind of output, the ordered list of sisulets that produce it. |
| `sisulets/` | The sisulets, in a folder for each kind of output (`source`, `target`, `workflow`, `format`, `biml`), and the ones they share. |
| `metadata/` | The scripts that create the metadata model, which is itself an Anchor model (`MetadataModel.xml`), with its logging and utility procedures. |
| `stats/` | An optional model and procedure for gathering statistics. |
| `code/` | The CLR utilities (`Utilities<year>.dll`, their `.SHA512` files and the source, `Utilities.cs`), the XSDs of the three XML formats (`source.xsd`, `target.xsd`, `workflow.xsd`), the bundled Jint, and a loading report. |
| `Examples/` | The Golf and Traffic projects. |
| `ETL Editor.html` | A stand-alone page for editing target definitions. Open it in a browser, open a target XML file, edit the loads and their mappings, including the SQL before, the SELECT and the SQL after, and download the result. |
| `Sign-Sisulate.ps1` | Signs `Sisulate.ps1` with a self-signed certificate, for machines that only run signed scripts. |
| `Sisulate.bat`, `SisulateWSH.bat`, `Sisulator.hta`, `Sisulator.js` | The legacy generators, in batch, HTA and JScript. They are deprecated, and kept for as long as Windows can still run them. |

## Not the same as the sisula repository

This framework was developed in the [sisula](https://github.com/Roenbaeck/sisula) repository, and was its `ETL` branch until 2026-09-30, when it moved here with its history and tags.

The Sisulator in this repository is the original dialect of Sisula: a sisulet is JavaScript with embedded text templates, translated to JavaScript with regular expressions and then run. The sisula repository now holds a different template language of the same name, declarative and driven by JSON, with a reference renderer and a set of conformance tests. The two are not interchangeable, and this framework does not use the newer one. Whenever this document says Sisula or the Sisulator, it means the one described here.

## License

MIT, see [LICENSE](LICENSE).

## History

Sisula was introduced in [Anchor Modeling](http://www.anchormodeling.com) in order to replace XSLT for producing text output, and a first JavaScript version of the Sisulator is built into its [modeling tool](http://code.google.com/p/anchormodeler). This framework is derived from that work.

---

## Reference: the Sisulator and sisulets

### 1. Introduction: The Sisula Concept

Sisula is a hybrid ETL transformation engine that combines procedural JavaScript logic with embedded text generation templates. It is designed to read source XML metadata and transform it into executable SQL code, configuration files (like BCP formats), and other artifacts.

**Core Philosophy:** Sisula prioritizes developer productivity by allowing complex, stateful logic to be written in standard JavaScript, rather than a purely declarative language like XSLT. A transformation process is defined by a set of "sisulet" files which are concatenated and executed to produce a single text output.

**Key Components:**

*   **XML Metadata Files:** The input data describing sources, targets, or workflows.
*   **Sisulet Files (`.js`):** The building blocks of a transformation. These can contain either pure JavaScript logic or text templates.
*   **Directive Files (`.directive`):** A manifest file that lists, in order, all sisulet files required for a specific transformation (e.g., generating a source loading procedure).
*   **The Sisulator Engine:** The core logic (in `Sisulator4PS.js`, which `Sisulate.ps1` runs in Jint; `Sisulator.js` is the legacy JScript version) that parses input, manages context, processes sisulets, and generates the final output.

---

### 2. Getting Started: How a Transformation Works

A Sisula transformation follows a precise data flow:

1.  **Input:** The engine receives an input XML file (e.g., `MySource.xml`) and a context object containing global variables (`VARIABLES`).
2.  **Objectification:** The input XML is parsed into a JavaScript object structure. For example, `<source name="A"><part name="B"/></source>` becomes accessible via `source.name` and `source.part.B`.
3.  **Sisulet Collection:** The engine reads a directive file (e.g., `source.directive`) to gather a list of sisulet files.
4.  **Sandbox Execution:** The contents of all collected sisulets are combined and executed within a secure sandbox environment. This environment has access to the objectified XML and the context variables.
5.  **Template Processing:** The engine identifies special template blocks (`/*~ ... ~*/`) within the sisulets and processes them to generate text output, substituting variables as it goes.
6.  **Output:** The final concatenated text from the template processing is saved as the result file (e.g., `MySource.sql`).

---

### 3. Sisulet Syntax Reference

There are two types of content within a sisulet file: **Pure JavaScript Code** and **Template Blocks**.

#### 3.1 Pure JavaScript Code

Any text outside of a template block is treated as standard ECMAScript 5.1 JavaScript. This code is executed directly. It is primarily used to define helper functions, manipulate data structures, and prepare data for the templates.

**Example (`Helpers.js`):**

```javascript
// This function adds iterator methods to the source object.
// It allows templates to use simple loops like source.nextPart().
source._iterator = {};
source._iterator.part = 0;
source.nextPart = function() {
    if(!this.parts) return null;
    if(source._iterator.part == this.parts.length) {
        source._iterator.part = 0;
        return null;
    }
    return this.part[this.parts[source._iterator.part++]];
};
```

#### 3.2 Template Blocks (`/*~ ... ~*/`)

Template blocks are sections of code specifically designed for text generation. They are initiated by `/*~` and terminated by `~*/`. The content inside these blocks is treated as literal text, except for special substitution patterns.

**Example:**

```javascript
/*~
CREATE PROCEDURE schema.sp_load_$source.name$
AS
BEGIN
~*/
// JavaScript logic can go between template blocks
var i = 1;
while(i <= 2) {
/*~
    -- Iteration $i$
~*/
    i++;
}
/*~
END;
~*/
```

**Output:**

```sql
CREATE PROCEDURE schema.sp_load_MySource
AS
BEGIN
    -- Iteration 1
    -- Iteration 2
END;
```

---

### 4. Variable Substitution Syntax

Within template blocks, variables are substituted using a concise, custom syntax.

#### 4.1 Simple Variable Replacement: `$variable$`

Replaces a placeholder with the value of a JavaScript variable from the current scope. If the variable does not exist or is `null`, it is replaced with an empty string.

*   **Syntax:** `$variableName$` or `$object.property$`
*   **Example:** `COLUMN_NAME = $term.name$;`
*   **Output:** `COLUMN_NAME = CustomerID;`

#### 4.2 Complex Expression Replacement: `${expression}$`

Executes a JavaScript expression and replaces the placeholder with the result. This allows for calculations or function calls inline.

*   **Syntax:** `${javascriptExpression}$`
*   **Example:** `ITEM_ID = ${part.id + '_' + term.id}$;`
*   **Output:** `ITEM_ID = B_CustomerID;`

#### 4.3 Conditional Expression (Ternary Operator): `$(condition)?true_value:false_value`

Evaluates a JavaScript condition. If true, outputs `true_value`; otherwise, outputs `false_value`. This is a shorthand for a common `if/else` pattern.

*   **Syntax:** `$(condition)?output_if_true:output_if_false`
    *   Note: The `:false_value` part is optional.
*   **Example:** `IS_NULLABLE = $(term.nullable == 'true')?1:0;`
*   **Output:** `IS_NULLABLE = 1;`

---

### 5. Core Sisulets and Best Practices

#### 5.1 Key Sisulets Explained

*   **`Polyfills.js`:** Provides implementations of modern JavaScript methods for older engines (no longer strictly necessary with Jint but kept for structure).
*   **`Variables.js`:** Contains global helper functions, such as `replaceVariables`, which performs recursive placeholder substitution on data objects. This is critical for resolving nested variables (e.g., when a variable's value contains another variable).
*   **`Helpers.js` (`source/Helpers.js`, etc.):** This is one of the most important files. It implements the iterator logic (`.nextPart()`, `.nextTerm()`) that enables simple `while` loops in other sisulets. It bridges the gap between the static data object and a stateful-iteration programming model.

#### 5.2 Best Practices and Data Flow

1.  **Data Preparation First:** Sisulets listed first in a `.directive` file (like `Helpers.js`) should focus on preparing data and defining functions. Sisulets listed later should focus on using those functions to generate output.
2.  **Context Scoping:** Variables defined in `VARIABLES` are global. The `workflow/Variables.js` script demonstrates best practice for creating scoped copies of variables for nested elements like jobs (`job.VARIABLES = copyVariables(workflow.VARIABLES);`), preventing child elements from accidentally modifying the parent's context.
3.  **Variable Resolution Order:** Be aware that variable substitution can be order-dependent. The `replaceVariables` function should be called strategically to resolve placeholders within data *before* that data is used to resolve placeholders in templates. (As we saw with the multi-stage replacement fix for workflows).
