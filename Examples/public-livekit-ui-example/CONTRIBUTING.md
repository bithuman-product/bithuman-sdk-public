# Contributing to bitHuman LiveKit UI Example

Thank you for your interest in contributing to the bitHuman LiveKit UI Example! We welcome contributions from the community and are excited to see what you'll build.

## 🤝 How to Contribute

### Reporting Issues

If you find a bug or have a suggestion for improvement:

1. **Search existing issues** to see if your issue has already been reported
2. **Create a new issue** with a clear title and description
3. **Provide details** about your environment (OS, browser, Node.js version)
4. **Include steps to reproduce** the issue if it's a bug
5. **Add screenshots** or code examples if helpful

### Submitting Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Install dependencies** with `npm install`
3. **Make your changes** following our coding standards
4. **Test your changes** thoroughly
5. **Update documentation** if necessary
6. **Submit a pull request** with a clear description

### Development Setup

```bash
# Clone your fork
git clone https://github.com/bithuman-product/examples.git
cd bithuman-livekit-ui-example

# Install dependencies
npm install

# Create environment file
cp env.template .env
# Edit .env with your LiveKit credentials

# Start development server
npm run dev
```

## 📋 Guidelines

### Code Style

- **TypeScript** - Use TypeScript for all new code
- **ESLint** - Follow the existing ESLint configuration
- **Prettier** - Code will be automatically formatted
- **Components** - Use functional components with hooks
- **Naming** - Use descriptive names for variables and functions

### UI/UX Guidelines

- **Responsive Design** - Ensure components work on all screen sizes
- **Accessibility** - Follow WCAG guidelines for accessibility
- **Performance** - Optimize for fast loading and smooth animations
- **Glassmorphism** - Maintain the existing design language
- **User Experience** - Keep interactions intuitive and smooth

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add voice activity indicator to control panel
fix: resolve connection timeout issues
docs: update installation instructions
style: improve button hover animations
```

### Pull Request Process

1. **Update README.md** if you're changing functionality
2. **Add/update tests** for new features
3. **Ensure CI passes** (linting, type checking, build)
4. **Request review** from maintainers
5. **Address feedback** promptly

## 🎯 What We're Looking For

### High Priority

- **Performance improvements** - Faster loading, smoother animations
- **Accessibility enhancements** - Better screen reader support, keyboard navigation
- **Mobile optimizations** - Improved mobile experience
- **Documentation** - Better examples, tutorials, API docs
- **Testing** - Unit tests, integration tests, e2e tests

### Feature Ideas

- **Advanced UI components** - Additional control panels, settings
- **Customization options** - Theming, layout options
- **Integration examples** - Different agent types, deployment scenarios
- **Developer tools** - Debugging utilities, monitoring dashboards
- **Internationalization** - Multi-language support

### Not Accepting

- **Breaking changes** without discussion
- **Major architectural changes** without proposal
- **Features unrelated to LiveKit/bitHuman integration**
- **Dependencies with licensing issues**

## 🧪 Testing

### Running Tests

```bash
# Run linting
npm run lint

# Run type checking
npm run type-check

# Run build test
npm run build
```

### Test Coverage

- **Unit tests** for utility functions
- **Component tests** for React components
- **Integration tests** for LiveKit connections
- **E2E tests** for critical user flows

## 📖 Documentation

### Documentation Standards

- **Clear examples** with code snippets
- **Step-by-step guides** for common tasks
- **API documentation** for public interfaces
- **Troubleshooting guides** for common issues

### Writing Style

- **Concise and clear** - Get to the point quickly
- **Examples first** - Show code before explaining
- **User-focused** - Write for developers using the example
- **Update frequently** - Keep docs in sync with code

## 🏷️ Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements or additions to docs
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `question` - Further information is requested

## 💬 Community

### Getting Help

- **GitHub Issues** - For bugs and feature requests
- **GitHub Discussions** - For questions and community chat
- **bitHuman Discord** - For real-time community support
- **Documentation** - Check the README and docs first

### Code of Conduct

- **Be respectful** - Treat everyone with kindness and respect
- **Be inclusive** - Welcome people of all backgrounds and experience levels
- **Be constructive** - Focus on helping and improving
- **Be patient** - Remember that everyone is learning

## 🎉 Recognition

Contributors will be:

- **Listed in README** - Added to contributors section
- **Credited in releases** - Mentioned in release notes
- **Invited to discussions** - Included in planning conversations
- **Appreciated publicly** - Thanked on social media

## 📄 License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

**Thank you for contributing to the bitHuman LiveKit UI Example!** 🙏

Your contributions help make real-time AI agent interfaces better for everyone. 