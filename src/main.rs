use clap::{Parser, ValueEnum};
use std::io::Write;
use std::{os::unix::fs::PermissionsExt, path::PathBuf, process::Command};

#[derive(Parser, Debug)]
#[command(version, about = "Generate Nix flake templates for projects")]
struct Cli {
    /// Include comments in generated files
    #[arg(short = 'c', long = "comments")]
    comments: bool,

    /// Language template to use
    #[arg(value_enum)]
    lang: Language,

    /// Target directory (defaults to current directory)
    path: Option<PathBuf>,
}

#[derive(ValueEnum, Clone, Debug, PartialEq)]
enum Language {
    Agnostic,
    Rust,
}

impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Agnostic => write!(f, "agnostic"),
            Language::Rust => write!(f, "rust"),
        }
    }
}

#[derive(Debug)]
enum Error {
    #[allow(dead_code)]
    Io(std::io::Error),
    #[allow(dead_code)]
    TemplateError(String),
    NixFmtFailed,
    NixFmtNotFound,
}

impl From<std::io::Error> for Error {
    fn from(io_err: std::io::Error) -> Error {
        Error::Io(io_err)
    }
}

fn main() -> Result<(), Error> {
    let cli = Cli::parse();

    // Determine target directory
    let base_path = match cli.path.clone() {
        None => std::env::current_dir()?,
        Some(path) if path.to_str() == Some(".") => std::env::current_dir()?,
        Some(path) => {
            if !path.exists() {
                std::fs::create_dir_all(&path)?;
            }
            path
        }
    };

    // Get templates directory
    let templates_dir = std::env::var("TEMPLATES_DIR").unwrap_or_else(|_| "templates".to_string());
    let lang_templates_dir = format!("{}/{}", templates_dir, cli.lang);

    // Read and write flake.nix
    let flake_template = read_template(&format!("{}/flake.nix.template", lang_templates_dir))?;
    let flake_content = if cli.comments {
        flake_template
    } else {
        strip_comments(&flake_template)
    };
    let flake_path = get_unique_path(&base_path, "flake", "nix");
    write_file(&flake_path, &flake_content)?;
    format_flake(&flake_path)?;

    // Read and write scripts.nix (only for Rust)
    if cli.lang == Language::Rust {
        let scripts_template =
            read_template(&format!("{}/scripts.nix.template", lang_templates_dir))?;
        let scripts_content = if cli.comments {
            scripts_template
        } else {
            strip_comments(&scripts_template)
        };
        let scripts_path = get_unique_path(&base_path, "scripts", "nix");
        write_file(&scripts_path, &scripts_content)?;
    }

    // Read and append .gitignore
    let gitignore_template = read_template(&format!("{}/gitignore.template", lang_templates_dir))?;
    let gitignore_content = if cli.comments {
        gitignore_template
    } else {
        strip_comments(&gitignore_template)
    };
    let gitignore_path = base_path.join(".gitignore");
    append_to_file(&gitignore_path, &gitignore_content)?;

    // Create .envrc
    let envrc_path = base_path.join(".envrc");
    append_to_file(&envrc_path, "use flake . -Lv")?;

    Ok(())
}

fn read_template(path: &str) -> Result<String, Error> {
    std::fs::read_to_string(path)
        .map_err(|e| Error::TemplateError(format!("Failed to read template {}: {}", path, e)))
}

fn strip_comments(content: &str) -> String {
    content
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            // Skip lines that are only comments
            if trimmed.starts_with('#') {
                return None;
            }
            // Remove inline comments
            if let Some(pos) = line.find(" # ") {
                Some(line[..pos].to_string())
            } else if let Some(pos) = line.find(" #<-") {
                Some(line[..pos].to_string())
            } else {
                Some(line.to_string())
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn get_unique_path(base_path: &PathBuf, name: &str, ext: &str) -> PathBuf {
    let mut path = base_path.join(format!("{}.{}", name, ext));
    if !path.exists() {
        return path;
    }

    let mut counter = 1;
    loop {
        path = base_path.join(format!("{}_{}.{}", name, counter, ext));
        if !path.exists() {
            println!("{}.{} taken, made {}_{}.{}", name, ext, name, counter, ext);
            return path;
        }
        counter += 1;
    }
}

fn write_file(path: &PathBuf, content: &str) -> Result<(), Error> {
    std::fs::write(path, content)?;
    let mut permissions = std::fs::metadata(path)?.permissions();
    permissions.set_mode(0o644);
    std::fs::set_permissions(path, permissions)?;
    Ok(())
}

fn append_to_file(path: &PathBuf, content: &str) -> Result<(), Error> {
    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?;

    // Check if the file is empty. If not, add a newline prefix.
    let metadata = file.metadata()?;
    let mut prefix = "";
    if metadata.len() > 0 {
        prefix = "\n# Added by flake-gen\n";
    }

    let text = format!("{}{}", prefix, content);
    file.write_all(text.as_bytes())?;

    let mut permissions = std::fs::metadata(path)?.permissions();
    permissions.set_mode(0o644);
    std::fs::set_permissions(path, permissions)?;

    Ok(())
}

fn format_flake(flake_path: &PathBuf) -> Result<(), Error> {
    let nixfmt_check = Command::new("which").arg("nixfmt").output();

    if let Ok(output) = nixfmt_check {
        if output.status.success() {
            let format_result = Command::new("nixfmt").arg(flake_path).status();

            match format_result {
                Ok(status) if status.success() => Ok(()),
                _ => Err(Error::NixFmtFailed),
            }
        } else {
            Err(Error::NixFmtNotFound)
        }
    } else {
        Err(Error::NixFmtNotFound)
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use assert_cmd::Command;
    use tempdir::TempDir;

    fn flake_gen_cmd() -> Command {
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        let templates_dir = std::env::current_dir().unwrap().join("templates");
        cmd.env("TEMPLATES_DIR", templates_dir);
        cmd
    }

    fn diff(file1: PathBuf, file2: PathBuf) -> Option<String> {
        let output = Command::new("diff")
            .arg("-u")
            .arg(&file1)
            .arg(&file2)
            .output()
            .expect("Failed to run diff command");

        let code = output.status.code().expect("Failed to get err code");
        if code == 0 {
            return None;
        };
        if code != 1 {
            panic!("Unknown status code")
        };

        Some(String::from_utf8_lossy(&output.stdout).to_string())
    }

    #[test]
    fn test_rust_with_comments() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let tests_dir: PathBuf = ["tests", "rust", "with_comments"].iter().collect();

        let mut cmd = flake_gen_cmd();
        cmd.args(["-c", "rust", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Compare flake
        let expected_flake = temp_dir.path().join("flake.nix");
        let actual_flake = tests_dir.join("flake.nix");
        if let Some(diff_content) = diff(actual_flake, expected_flake) {
            panic!(
                "Generated flake.nix with comments for rust doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };

        // Compare scripts
        let expected_scripts = temp_dir.path().join("scripts.nix");
        let actual_scripts = tests_dir.join("scripts.nix");
        if let Some(diff_content) = diff(actual_scripts, expected_scripts) {
            panic!(
                "Generated scripts.nix with comments for rust doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };

        // Compare gitignore
        let expected_gitignore = temp_dir.path().join(".gitignore");
        let actual_gitignore = tests_dir.join("gitignore");
        if let Some(diff_content) = diff(expected_gitignore, actual_gitignore) {
            panic!(
                "Generated gitignore with comments for rust doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };

        // Compare envrc
        let expected_envrc = temp_dir.path().join(".envrc");
        let actual_envrc = tests_dir.join("envrc");
        if let Some(diff_content) = diff(expected_envrc, actual_envrc) {
            panic!(
                "Generated envrc with comments for rust doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };
    }

    #[test]
    fn test_rust_no_comments() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let tests_dir: PathBuf = ["tests", "rust", "no_comments"].iter().collect();

        let mut cmd = flake_gen_cmd();
        cmd.args(["rust", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Compare flake
        let expected_flake = temp_dir.path().join("flake.nix");
        let actual_flake = tests_dir.join("flake.nix");
        if let Some(diff_content) = diff(actual_flake, expected_flake) {
            panic!(
                "Generated flake.nix without comments for rust doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };
    }

    #[test]
    fn test_agnostic_with_comments() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let tests_dir: PathBuf = ["tests", "agnostic", "with_comments"].iter().collect();

        let mut cmd = flake_gen_cmd();
        cmd.args(["-c", "agnostic", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Compare flake
        let expected_flake = temp_dir.path().join("flake.nix");
        let actual_flake = tests_dir.join("flake.nix");
        if let Some(diff_content) = diff(actual_flake, expected_flake) {
            panic!(
                "Generated flake.nix with comments for agnostic doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };

        // Verify no scripts.nix created
        assert!(
            !temp_dir.path().join("scripts.nix").exists(),
            "scripts.nix should not exist for agnostic"
        );

        // Compare gitignore
        let expected_gitignore = temp_dir.path().join(".gitignore");
        let actual_gitignore = tests_dir.join("gitignore");
        if let Some(diff_content) = diff(expected_gitignore, actual_gitignore) {
            panic!(
                "Generated gitignore with comments for agnostic doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };

        // Compare envrc
        let expected_envrc = temp_dir.path().join(".envrc");
        let actual_envrc = tests_dir.join("envrc");
        if let Some(diff_content) = diff(expected_envrc, actual_envrc) {
            panic!(
                "Generated envrc with comments for agnostic doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };
    }

    #[test]
    fn test_agnostic_no_comments() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let tests_dir: PathBuf = ["tests", "agnostic", "no_comments"].iter().collect();

        let mut cmd = flake_gen_cmd();
        cmd.args(["agnostic", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Compare flake
        let expected_flake = temp_dir.path().join("flake.nix");
        let actual_flake = tests_dir.join("flake.nix");
        if let Some(diff_content) = diff(actual_flake, expected_flake) {
            panic!(
                "Generated flake.nix without comments for agnostic doesn't match expected.\nDiff:\n{}",
                diff_content
            )
        };
    }

    #[test]
    fn test_file_collision_creates_numbered_file() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();

        // Create existing flake.nix
        std::fs::write(temp_dir.path().join("flake.nix"), "existing").unwrap();

        let mut cmd = flake_gen_cmd();
        cmd.args(["agnostic", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Verify flake_1.nix was created
        assert!(
            temp_dir.path().join("flake_1.nix").exists(),
            "flake_1.nix should be created"
        );
        // Verify original was not touched
        assert_eq!(
            std::fs::read_to_string(temp_dir.path().join("flake.nix")).unwrap(),
            "existing"
        );
    }

    #[test]
    fn test_append_to_existing_gitignore() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();

        // Create existing .gitignore
        std::fs::write(temp_dir.path().join(".gitignore"), "node_modules/\n").unwrap();

        let mut cmd = flake_gen_cmd();
        cmd.args(["agnostic", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Verify content was appended
        let content = std::fs::read_to_string(temp_dir.path().join(".gitignore")).unwrap();
        assert!(
            content.starts_with("node_modules/\n"),
            "Original content should be preserved"
        );
        assert!(
            content.contains("# Added by flake-gen"),
            "Should have flake-gen header"
        );
        assert!(content.contains(".direnv"), "Should have appended content");
    }

    #[test]
    fn test_append_to_existing_envrc() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();

        // Create existing .envrc
        std::fs::write(temp_dir.path().join(".envrc"), "export FOO=bar\n").unwrap();

        let mut cmd = flake_gen_cmd();
        cmd.args(["agnostic", temp_dir.path().to_str().unwrap()])
            .assert()
            .success();

        // Verify content was appended
        let content = std::fs::read_to_string(temp_dir.path().join(".envrc")).unwrap();
        assert!(
            content.starts_with("export FOO=bar\n"),
            "Original content should be preserved"
        );
        assert!(
            content.contains("use flake . -Lv"),
            "Should have appended content"
        );
    }

    #[test]
    fn test_creates_directory_if_not_exists() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let project_path = temp_dir.path().join("my-project");

        let mut cmd = flake_gen_cmd();
        cmd.args(["rust", project_path.to_str().unwrap()])
            .assert()
            .success();

        assert!(project_path.exists(), "Project directory should be created");
        assert!(
            project_path.join("flake.nix").exists(),
            "flake.nix should exist"
        );
    }

    #[test]
    fn test_invalid_arguments() {
        // No language specified
        let mut cmd = flake_gen_cmd();
        cmd.assert().failure().stderr(predicates::str::contains(
            "required arguments were not provided",
        ));

        // Invalid language
        let mut cmd = flake_gen_cmd();
        cmd.arg("invalid-language")
            .assert()
            .failure()
            .stderr(predicates::str::contains(
                "invalid value 'invalid-language' for '<LANG>'",
            ));

        // Invalid flag
        let mut cmd = flake_gen_cmd();
        cmd.args(["-z", "agnostic"])
            .assert()
            .failure()
            .stderr(predicates::str::contains("unexpected argument"));
    }

    #[test]
    fn test_current_dir_default() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();

        let mut cmd = flake_gen_cmd();
        cmd.current_dir(temp_dir.path())
            .args(["rust"])
            .assert()
            .success();

        assert!(
            temp_dir.path().join("flake.nix").exists(),
            "flake.nix should exist in current dir"
        );
    }

    #[test]
    fn test_dot_path_means_current_dir() {
        let temp_dir = TempDir::new("flake-gen-test").unwrap();

        let mut cmd = flake_gen_cmd();
        cmd.current_dir(temp_dir.path())
            .args(["rust", "."])
            .assert()
            .success();

        assert!(
            temp_dir.path().join("flake.nix").exists(),
            "flake.nix should exist in current dir"
        );
    }
}
