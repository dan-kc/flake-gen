use clap::{Parser, ValueEnum};
use std::{os::unix::fs::PermissionsExt, path::PathBuf, process::Command};
use strum::EnumIter;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short = 'c', help = "Add comments to flake.nix")]
    comments: bool,
    #[arg(short = 'p', help = "Add package to flake.nix")]
    package: bool,
    #[arg(short = 'd', help = "Add a dev shell and an .envrc file")]
    dev: bool,
    #[arg(short = 'g', help = "Add .gitignore file")]
    git: bool,
    #[arg(value_enum)]
    lang: Language,
    path: Option<PathBuf>,
}

#[derive(ValueEnum, Clone, Debug, EnumIter)]
enum Language {
    Agnostic,
    Rust,
    Go,
    Python,
    Typescript,
    Cpp,
    Terraform,
    Elixir,
}

impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Agnostic => write!(f, "agnostic"),
            Language::Rust => write!(f, "rust"),
            Language::Go => write!(f, "go"),
            Language::Python => write!(f, "python"),
            Language::Typescript => write!(f, "typescript"),
            Language::Cpp => write!(f, "cpp"),
            Language::Terraform => write!(f, "terraform"),
            Language::Elixir => write!(f, "elixir"),
        }
    }
}

#[derive(Debug)]
#[allow(dead_code)]
enum Error {
    Io(std::io::Error),
    NixFileAlreadyExists,
    EnvrcFileAlreadyExists,
    GitIgnoreAlreadyExists,
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
    let base_path = match cli.path.clone() {
        None => std::env::current_dir()?,
        Some(path) => path,
    };

    // Error if flake.nix exists
    let mut flake_path = base_path.clone();
    flake_path.push("flake.nix");
    if flake_path.exists() {
        return Err(Error::NixFileAlreadyExists);
    }

    // Error if dev flag picked and .envrc exists
    if cli.dev {
        let mut envrc_path = base_path.clone();
        envrc_path.push(".envrc");
        if envrc_path.exists() {
            return Err(Error::EnvrcFileAlreadyExists);
        }
    };

    // Error if git flag picked and .gitignore exists
    if cli.git {
        let mut gitignore_path = base_path.clone();
        gitignore_path.push(".gitignore");
        if gitignore_path.exists() {
            return Err(Error::GitIgnoreAlreadyExists);
        }
    };

    // If the disired path does not exist, then create it
    if let Some(ref path) = cli.path {
        if !path.exists() {
            std::fs::create_dir_all(path)?;
        }
    }

    // Load the templates
    let templates_dir = std::env::var("TEMPLATES_DIR").unwrap_or_else(|_| "templates".to_string());
    let template_path = format!("{}/*.template", templates_dir);
    let tera = match tera::Tera::new(&template_path) {
        Ok(t) => t,
        Err(e) => {
            println!("Parsing error(s): {}", e);
            ::std::process::exit(1);
        }
    };

    // Insert context
    let mut context = tera::Context::new();
    context.insert("dev", &cli.dev);
    context.insert("package", &cli.package);
    context.insert("comments", &cli.comments);
    context.insert("docker_image", &cli.package); // Docker image is enabled when package is

    // Get filename
    let mut flake_template_name = cli.lang.to_string();
    flake_template_name.push_str(".template");

    // Render and save flake
    let rendered_flake = tera.render(flake_template_name.as_str(), &context).unwrap();
    std::fs::write(&flake_path, rendered_flake)?;
    let mut permissions = std::fs::metadata(&flake_path)?.permissions();
    permissions.set_mode(0o644);
    std::fs::set_permissions(&flake_path, permissions)?;

    // Format the flake.nix with nixfmt-rfc-style
    format_flake(&flake_path)?;

    // Render and save envrc
    if cli.dev {
        let mut envrc_path = base_path.clone();
        envrc_path.push(".envrc");
        let envrc = "use flake . -Lv";
        std::fs::write(&envrc_path, envrc)?;
        let mut permissions = std::fs::metadata(&envrc_path)?.permissions();
        permissions.set_mode(0o644);
        std::fs::set_permissions(envrc_path, permissions)?;
    };

    // Render and save gitignore
    if cli.git {
        let mut gitignore_path = base_path.clone();
        gitignore_path.push(".gitignore");
        let gitignore = ".direnv/";
        std::fs::write(&gitignore_path, gitignore)?;
        let mut permissions = std::fs::metadata(&gitignore_path)?.permissions();
        permissions.set_mode(0o644);
        std::fs::set_permissions(gitignore_path, permissions)?;
    };

    Ok(())
}

fn format_flake(flake_path: &PathBuf) -> Result<(), Error> {
    // Check if nixfmt-rfc-style is available
    let nixfmt_check = Command::new("which").arg("nixfmt").output();

    // Verify nixfmt-rfc-style is available
    if let Ok(output) = nixfmt_check {
        if output.status.success() {
            let format_result = Command::new("nixfmt").arg(flake_path).status();

            match format_result {
                Ok(status) if status.success() => Ok(()),
                _ => Err(Error::NixFmtFailed),
            }
        } else {
            // nixfmt-rfc-style not found, return an error
            Err(Error::NixFmtNotFound)
        }
    } else {
        // Error running which command, return an error
        Err(Error::NixFmtNotFound)
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use assert_cmd::Command;
    use strum::IntoEnumIterator;
    use tempdir::TempDir;

    use crate::Language;

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
    fn test_all_languages_all_flags() {
        for lang in Language::iter() {
            let lang_str = lang.to_string();
            let temp_dir = TempDir::new("flake-gen-test").unwrap();
            let tests_dir: PathBuf = ["tests", &lang_str, "all_flags"].iter().collect();

            // Run flake-gen with all flags
            let mut cmd = Command::cargo_bin("flake-gen").unwrap();
            cmd.args([
                "-c",
                "-p",
                "-d",
                "-g",
                &lang_str,
                temp_dir.path().to_str().unwrap(),
            ])
            .assert()
            .success();

            // Compare flake
            let expected_flake = temp_dir.path().join("flake.nix");
            let actual_flake = tests_dir.join("flake.nix");
            if let Some(diff_content) = diff(actual_flake, expected_flake) {
                panic!(
                    r#"Generated flake.nix with all flags for {} doesn't match expected.
                    Diff:
                    {}
                    "#,
                    lang_str, diff_content
                )
            };

            // Compare gitignore
            let expected_gitignore = temp_dir.path().join(".gitignore");
            let actual_gitignore = tests_dir.join("gitignore");
            if let Some(diff_content) = diff(expected_gitignore, actual_gitignore) {
                panic!(
                    r#"Generated gitignore with all flags for {} doesn't match expected.
                    Diff:
                    {}
                    "#,
                    lang_str, diff_content
                )
            };

            // Compare envrc
            let expected_envrc = temp_dir.path().join(".envrc");
            let actual_envrc = tests_dir.join("envrc");
            if let Some(diff_content) = diff(expected_envrc, actual_envrc) {
                panic!(
                    r#"Generated envrc with all flags for {} doesn't match expected.
                    Diff:
                    {}
                    "#,
                    lang_str, diff_content
                )
            };
        }
    }

    #[test]
    fn test_all_languages_no_flags() {
        for lang in Language::iter() {
            let lang_str = lang.to_string();
            let temp_dir = TempDir::new("flake-gen-test").unwrap();
            let tests_dir: PathBuf = ["tests", &lang_str, "no_flags"].iter().collect();

            // Run command with no flags
            let mut cmd = Command::cargo_bin("flake-gen").unwrap();
            cmd.args([&lang_str, temp_dir.path().to_str().unwrap()])
                .assert()
                .success();

            // Compare flake
            let expected_flake = temp_dir.path().join("flake.nix");
            let actual_flake = tests_dir.join("flake.nix");
            if let Some(diff_content) = diff(actual_flake, expected_flake) {
                panic!(
                    r#"Generated flake.nix with no flags for {} doesn't match expected.
                    Diff:
                    {}
                    "#,
                    lang_str, diff_content
                )
            };
        }
    }

    #[test]
    fn test_invalid_arguments() {
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.assert().failure().stderr(predicates::str::contains(
            "required arguments were not provided",
        ));

        // Test invalid language
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.arg("invalid-language")
            .assert()
            .failure()
            .stderr(predicates::str::contains(
                "invalid value 'invalid-language' for '<LANG>'",
            ));

        // Test invalid flag
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.args(["-z", "agnostic"])
            .assert()
            .failure()
            .stderr(predicates::str::contains("unexpected argument"));
    }

    #[test]
    fn test_file_exists_errors() {
        // Setup a temp directory
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let temp_path = temp_dir.path().to_str().unwrap();

        // Create flake.nix
        std::fs::write(temp_dir.path().join("flake.nix"), "").unwrap();

        // Test flake.nix already exists error
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.args(["agnostic", temp_path]).assert().failure();

        // Setup a temp directory with .envrc
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let temp_path = temp_dir.path().to_str().unwrap();
        std::fs::write(temp_dir.path().join(".envrc"), "").unwrap();

        // Test .envrc already exists error
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.args(["-d", "agnostic", temp_path]).assert().failure();

        // Setup a temp directory with .gitignore
        let temp_dir = TempDir::new("flake-gen-test").unwrap();
        let temp_path = temp_dir.path().to_str().unwrap();
        std::fs::write(temp_dir.path().join(".gitignore"), "").unwrap();

        // Test .gitignore already exists error
        let mut cmd = Command::cargo_bin("flake-gen").unwrap();
        cmd.args(["-g", "agnostic", temp_path]).assert().failure();
    }
}
