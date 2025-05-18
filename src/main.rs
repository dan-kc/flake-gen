use std::os::unix::fs::PermissionsExt;

use camino::Utf8PathBuf;
use clap::{Parser, Subcommand};
use strum::EnumIter;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    lang: Language,
}
impl Cli {
    fn path(&self) -> Utf8PathBuf {
        let curr_dir = Utf8PathBuf::from(".");
        match &self.lang {
            Language::Agnostic { path, .. } => path.clone().unwrap_or(curr_dir),
        }
    }
    fn dev(&self) -> bool {
        match self.lang {
            Language::Agnostic { dev, .. } => dev,
        }
    }
}

#[derive(Subcommand, Clone, Debug, EnumIter)]
enum Language {
    Agnostic {
        #[arg(short = 'c')]
        comments: bool,
        #[arg(short = 'p')]
        package: bool,
        #[arg(short = 'd')]
        dev: bool,
        #[arg(short = 'g')]
        git: bool,

        path: Option<Utf8PathBuf>,
    },
}
impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Agnostic { .. } => write!(f, "agnostic"),
        }
    }
}

#[derive(Debug)]
#[allow(dead_code)]
enum Error {
    Io(std::io::Error),
    NixFileAlreadyExists,
    EnvrcFileAlreadyExists,
    GitFileAlreadyExists,
    GitIgnoreAlreadyExists,
}
impl From<std::io::Error> for Error {
    fn from(io_err: std::io::Error) -> Error {
        Error::Io(io_err)
    }
}

fn main() -> Result<(), Error> {
    let cli = Cli::parse();
    let base_path = cli.path();

    // Error if flake.nix exists
    let mut flake_path = cli.path();
    flake_path.push("flake.nix");
    if flake_path.exists() {
        return Err(Error::NixFileAlreadyExists);
    }

    // Error if dev flag picked and .envrc exists
    if cli.dev() {
        let mut envrc_path = cli.path();
        envrc_path.push("flake.nix");
        if envrc_path.exists() {
            return Err(Error::EnvrcFileAlreadyExists);
        }
    };

    // If the disired path does not exist, then create it
    if !cli.path().exists() {
        std::fs::create_dir_all(cli.path())?;
    }

    // Read the template
    let template_path = "templates/*.nix";
    let tera = match tera::Tera::new(&template_path) {
        Ok(t) => t,
        Err(e) => {
            println!("Parsing error(s): {}", e);
            ::std::process::exit(1);
        }
    };

    // Render templates
    let rendered_templates = match cli.lang {
        #[allow(unused)]
        Language::Agnostic {
            path,
            dev,
            git,
            package,
            comments,
        } => {
            let mut context = tera::Context::new();
            context.insert("dev", &dev);
            context.insert("package", &package);
            context.insert("comments", &comments);
            let rendered_flake = tera.render("agnostic.nix", &context).unwrap();

            RenderedTemplates {
                flake: rendered_flake,
                envrc: None,
                gitignore: None,
            }
        }
    };

    rendered_templates.write(base_path)
}

#[allow(unused)]
pub struct RenderedTemplates {
    flake: String,
    envrc: Option<String>,
    gitignore: Option<String>,
}
impl RenderedTemplates {
    fn write(self, path: Utf8PathBuf) -> Result<(), Error> {
        // Get flake path
        let mut flake_path = path.clone();
        flake_path.push("flake.nix");

        // Create file
        std::fs::write(&flake_path, self.flake)?;

        // Set permissions
        let mut permissions = std::fs::metadata(&flake_path)?.permissions();
        permissions.set_mode(0o644);
        std::fs::set_permissions(flake_path, permissions)?;

        // Write envrc to .envrc
        match self.envrc {
            None => {}
            Some(envrc) => {
                // Get envrc path
                let mut envrc_path = path.clone();
                envrc_path.push(".envrc");

                // Create file
                std::fs::write(&envrc_path, envrc)?;

                // Set permissions
                let mut permissions = std::fs::metadata(&envrc_path)?.permissions();
                permissions.set_mode(0o644);
                std::fs::set_permissions(envrc_path, permissions)?;
            }
        };

        Ok(())
        // Append existing .gitignore
        // todo!()
    }
}

// #[cfg(test)]
// mod tests {
//     use super::Language;
//     use assert_cmd::Command;
//     use strum::IntoEnumIterator;
//
//     #[test]
//     fn test_correct_langs_and_valid_path() {
//         for lang in Language::iter() {
//             let lang_str = lang.to_string();
//             let temp_dir = tempdir::TempDir::new(
//                 ("test_correct_langs_and_valid_path ".to_string() + &lang_str).as_str(),
//             )
//             .unwrap();
//             let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//             cmd.args([lang_str.as_str(), temp_dir.path().to_str().unwrap()]);
//             cmd.assert().success().stdout(predicates::str::contains(
//                 "Succesfully created flake.nix and .envrc",
//             ));
//         }
//     }
//
//     #[test]
//     fn test_invalid_lang() {
//         let temp_dir = tempdir::TempDir::new("test_invalid_lang").unwrap();
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rus", temp_dir.path().to_str().unwrap()]);
//         cmd.assert().stderr(predicates::str::contains(""));
//     }
//
//     #[test]
//     fn test_invalid_flag() {
//         let temp_dir = tempdir::TempDir::new("invalid_flag").unwrap();
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rust", "--u", temp_dir.path().to_str().unwrap()]);
//         cmd.assert()
//             .stderr(predicates::str::contains("unexpected argument '--u' found"));
//     }
//
//     #[test]
//     fn test_no_path() {
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rust"]);
//         cmd.assert().stderr(predicates::str::contains(
//             "error: the following required arguments were not provided",
//         ));
//     }
// }
