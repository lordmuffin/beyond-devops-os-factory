# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **beyond-devops-os-factory**, an enterprise-grade OS image management automation framework. The project focuses on building reproducible Windows 11 Pro and SteamOS images using Infrastructure as Code (IaC) principles.

## Core Technologies & Architecture

- **Packer**: Primary tool for OS image building and automation
- **Ansible**: Configuration management and provisioning
- **GitHub Actions**: CI/CD pipeline automation
- **Security-first approach**: Built-in security scanning and compliance

## Project Structure

This is a new repository with minimal initial structure. The project is designed to implement:

- Automated OS image building pipelines
- Security scanning integration
- Reproducible infrastructure patterns
- Enterprise deployment workflows

## Development Context

The repository is currently in initial setup phase. Future development should focus on:

- Setting up Packer templates for Windows 11 Pro and SteamOS
- Implementing Ansible playbooks for configuration management
- Creating GitHub Actions workflows for automated testing
- Establishing security scanning and compliance checks

## Key Principles

- **Security-first**: All image builds should include security hardening
- **Reproducibility**: Images must be consistently reproducible across environments  
- **Enterprise-grade**: Solutions should meet enterprise compliance and operational requirements
- **IaC methodology**: All infrastructure and configuration should be code-driven