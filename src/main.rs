use clap::{Parser, ValueEnum};
use std::{os::unix::fs::PermissionsExt, path::PathBuf};
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
    let template_path = "templates/*.template";
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

    // Get filename
    let mut flake_template_name = cli.lang.to_string();
    flake_template_name.push_str(".template");

    // Render and save flake
    let rendered_flake = tera.render(flake_template_name.as_str(), &context).unwrap();
    std::fs::write(&flake_path, rendered_flake)?;
    let mut permissions = std::fs::metadata(&flake_path)?.permissions();
    permissions.set_mode(0o644);
    std::fs::set_permissions(flake_path, permissions)?;

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

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::fs::File;
    use std::io::Read;
    use std::path::PathBuf;

    use assert_cmd::Command;
    use strum::IntoEnumIterator;
    use tempdir::TempDir;

    use crate::Language;

    // Read all test files into memory once to avoid "too many files open" errors
    fn read_test_files() -> HashMap<String, HashMap<String, String>> {
        let mut test_files = HashMap::new();

        for lang in Language::iter() {
            let lang_str = lang.to_string();
            let lang_path = format!("tests/{}", lang_str);

            // Skip if the test directory doesn't exist for this language
            if !std::path::Path::new(&lang_path).exists() {
                continue;
            }

            let mut lang_files = HashMap::new();

            // Read all_flags files
            let all_flags_path = format!("{}/all_flags", lang_path);
            if std::path::Path::new(&all_flags_path).exists() {
                // Read flake.nix
                let flake_path = format!("{}/flake.nix", all_flags_path);
                if std::path::Path::new(&flake_path).exists() {
                    let mut flake_content = String::new();
                    File::open(&flake_path)
                        .unwrap()
                        .read_to_string(&mut flake_content)
                        .unwrap();
                    lang_files.insert("all_flags_flake".to_string(), flake_content);
                }

                // Read .envrc
                let envrc_path = format!("{}/envrc", all_flags_path);
                if std::path::Path::new(&envrc_path).exists() {
                    let mut envrc_content = String::new();
                    File::open(&envrc_path)
                        .unwrap()
                        .read_to_string(&mut envrc_content)
                        .unwrap();
                    lang_files.insert("all_flags_envrc".to_string(), envrc_content);
                }

                // Read .gitignore
                let gitignore_path = format!("{}/gitignore", all_flags_path);
                if std::path::Path::new(&gitignore_path).exists() {
                    let mut gitignore_content = String::new();
                    File::open(&gitignore_path)
                        .unwrap()
                        .read_to_string(&mut gitignore_content)
                        .unwrap();
                    lang_files.insert("all_flags_gitignore".to_string(), gitignore_content);
                }
            }

            // Read no_flags files
            let no_flags_path = format!("{}/no_flags", lang_path);
            if std::path::Path::new(&no_flags_path).exists() {
                // Read flake.nix
                let flake_path = format!("{}/flake.nix", no_flags_path);
                if std::path::Path::new(&flake_path).exists() {
                    let mut flake_content = String::new();
                    File::open(&flake_path)
                        .unwrap()
                        .read_to_string(&mut flake_content)
                        .unwrap();
                    lang_files.insert("no_flags_flake".to_string(), flake_content);
                }
            }

            test_files.insert(lang_str, lang_files);
        }

        test_files
    }

    fn read_generated_file(path: PathBuf) -> String {
        let mut content = String::new();
        if path.exists() {
            File::open(path)
                .unwrap()
                .read_to_string(&mut content)
                .unwrap();
        }
        content
    }

    #[test]
    fn test_all_languages_all_flags() {
        // Read all test files into memory first
        let test_files = read_test_files();

        for lang in Language::iter() {
            let lang_str = lang.to_string();

            // Skip if we don't have test files for this language
            if !test_files.contains_key(&lang_str) {
                println!("Skipping tests for {}, no test files found", lang_str);
                continue;
            }

            let temp_dir = TempDir::new("flake-gen-test").unwrap();
            let temp_path = temp_dir.path().to_str().unwrap();

            // Run command with all flags
            let mut cmd = Command::cargo_bin("flake-gen").unwrap();
            cmd.args(["-c", "-p", "-d", "-g", &lang_str, temp_path])
                .assert()
                .success();

            // Read generated files
            let flake_path = temp_dir.path().join("flake.nix");
            let flake_content = read_generated_file(flake_path);

            let envrc_path = temp_dir.path().join(".envrc");
            let envrc_content = read_generated_file(envrc_path);

            let gitignore_path = temp_dir.path().join(".gitignore");
            let gitignore_content = read_generated_file(gitignore_path);

            // Compare with expected content
            let lang_files = test_files.get(&lang_str).unwrap();

            if let Some(expected_flake) = lang_files.get("all_flags_flake") {
                assert_eq!(
                    flake_content, *expected_flake,
                    "Generated flake.nix with all flags for {} doesn't match expected",
                    lang_str
                );
            }

            if let Some(expected_envrc) = lang_files.get("all_flags_envrc") {
                assert_eq!(
                    envrc_content, *expected_envrc,
                    "Generated .envrc with all flags for {} doesn't match expected",
                    lang_str
                );
            }

            if let Some(expected_gitignore) = lang_files.get("all_flags_gitignore") {
                assert_eq!(
                    gitignore_content, *expected_gitignore,
                    "Generated .gitignore with all flags for {} doesn't match expected",
                    lang_str
                );
            }
        }
    }

    #[test]
    fn test_all_languages_no_flags() {
        // Read all test files into memory first
        let test_files = read_test_files();

        for lang in Language::iter() {
            let lang_str = lang.to_string();

            // Skip if we don't have test files for this language
            if !test_files.contains_key(&lang_str) {
                println!("Skipping tests for {}, no test files found", lang_str);
                continue;
            }

            let temp_dir = TempDir::new("flake-gen-test").unwrap();
            let temp_path = temp_dir.path().to_str().unwrap();

            // Run command with no flags
            let mut cmd = Command::cargo_bin("flake-gen").unwrap();
            cmd.args([&lang_str, temp_path]).assert().success();

            // Read generated flake.nix
            let flake_path = temp_dir.path().join("flake.nix");
            let flake_content = read_generated_file(flake_path);

            // Compare with expected content
            let lang_files = test_files.get(&lang_str).unwrap();

            if let Some(expected_flake) = lang_files.get("no_flags_flake") {
                assert_eq!(
                    flake_content, *expected_flake,
                    "Generated flake.nix with no flags for {} doesn't match expected",
                    lang_str
                );
            }

            // Verify that .envrc and .gitignore were not created
            let envrc_path = temp_dir.path().join(".envrc");
            assert!(
                !envrc_path.exists(),
                ".envrc should not exist for {} with no flags",
                lang_str
            );

            let gitignore_path = temp_dir.path().join(".gitignore");
            assert!(
                !gitignore_path.exists(),
                ".gitignore should not exist for {} with no flags",
                lang_str
            );
        }
    }

    #[test]
    fn test_invalid_arguments() {
        // Test missing required argument (language)
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
                "'invalid-language' isn't a valid value",
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
