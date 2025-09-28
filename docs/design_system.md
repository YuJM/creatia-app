# Creatia Design System

A comprehensive, accessible, and performant UI component library built for Rails 8 applications.

## Overview

The Creatia Design System is built on top of:
- **Rails 8** with ViewComponent for reusable components
- **Tailwind CSS** for utility-first styling
- **Stimulus** for interactive JavaScript behavior
- **WCAG 2.1 AA** accessibility standards

## Core Principles

### 1. Accessibility First
- Every component meets WCAG 2.1 AA standards
- Proper ARIA attributes and semantic HTML
- Keyboard navigation support
- Screen reader compatibility
- High contrast color combinations

### 2. Performance Optimized
- CSS custom properties for efficient theming
- Minimal JavaScript footprint
- Optimized animations and transitions
- Lazy loading for complex components

### 3. Developer Experience
- Consistent API patterns across components
- TypeScript-like parameter validation
- Comprehensive documentation and examples
- Easy customization and theming

## Architecture

### Component Structure
```
app/
├── components/
│   └── ui/
│       ├── button_component.rb
│       ├── button_component.html.erb
│       ├── card_component.rb
│       └── card_component.html.erb
├── javascript/
│   └── controllers/
│       ├── modal_controller.js
│       ├── theme_controller.js
│       └── tooltip_controller.js
└── assets/
    └── tailwind/
        └── application.css (design tokens and theming)
```

### CSS Architecture
- **Design Tokens**: CSS custom properties for colors, spacing, and typography
- **Component Classes**: Reusable base classes for common patterns
- **Utility Classes**: Tailwind utilities with design system extensions
- **Dark Mode**: CSS custom property based theme switching

## Color System

### Brand Colors

#### Primary (Blue)
- `primary-50` to `primary-950`: Main brand color with 11 shades
- Used for: Primary actions, links, focus states

#### Secondary (Gray)
- `secondary-50` to `secondary-950`: Neutral grays
- Used for: Text, borders, backgrounds

#### Accent (Teal)
- `accent-50` to `accent-950`: Complementary accent color
- Used for: Highlights, secondary actions

### Semantic Colors

#### Success (Green)
- `success-50` to `success-950`: Success states
- Used for: Success messages, positive actions

#### Warning (Amber)
- `warning-50` to `warning-950`: Warning states
- Used for: Warning messages, caution states

#### Danger (Red)
- `danger-50` to `danger-950`: Error states
- Used for: Error messages, destructive actions

### Usage Example
```erb
<%= render Ui::ButtonComponent.new(variant: :primary) { "Primary Button" } %>
<%= render Ui::ButtonComponent.new(variant: :danger) { "Delete" } %>
```

## Typography Scale

### Display Typography
- `text-display-2xl`: 2.5rem - 4.5rem (clamp)
- `text-display-xl`: 2rem - 3.75rem (clamp)
- `text-display-lg`: 1.75rem - 3rem (clamp)

### Standard Typography
- `text-4xl`: 2.25rem (36px)
- `text-3xl`: 1.875rem (30px)
- `text-2xl`: 1.5rem (24px)
- `text-xl`: 1.25rem (20px)
- `text-lg`: 1.125rem (18px)
- `text-base`: 1rem (16px)
- `text-sm`: 0.875rem (14px)
- `text-xs`: 0.75rem (12px)

### Font Weights
- `font-light`: 300
- `font-normal`: 400
- `font-medium`: 500
- `font-semibold`: 600
- `font-bold`: 700
- `font-extrabold`: 800

## Components

### Button Component

Flexible button component with multiple variants, sizes, and states.

#### Props
- `variant`: `:default`, `:secondary`, `:accent`, `:success`, `:warning`, `:danger`, `:outline`, `:ghost`, `:link`
- `size`: `:sm`, `:default`, `:lg`, `:xl`, `:icon`
- `disabled`: `true/false`
- `loading`: `true/false`
- `icon`: Symbol for icon name
- `icon_position`: `:left`, `:right`
- `full_width`: `true/false`

#### Examples
```erb
<%= render Ui::ButtonComponent.new(variant: :primary, icon: :plus) { "Add Item" } %>
<%= render Ui::ButtonComponent.new(variant: :danger, loading: true) { "Deleting..." } %>
<%= render Ui::ButtonComponent.new(size: :icon, icon: :settings) %>
```

### Input Component

Comprehensive form input component with validation states and accessibility features.

#### Props
- `type`: Input type (text, email, password, etc.)
- `size`: `:sm`, `:default`, `:lg`
- `label`: Label text
- `placeholder`: Placeholder text
- `required`: `true/false`
- `disabled`: `true/false`
- `readonly`: `true/false`
- `error`: Error message string
- `help_text`: Help text string
- `prefix`: Icon or text prefix
- `suffix`: Icon or text suffix

#### Examples
```erb
<%= render Ui::InputComponent.new(
  label: "Email Address",
  type: "email",
  prefix: :email,
  required: true,
  placeholder: "you@example.com"
) %>

<%= render Ui::InputComponent.new(
  label: "Username",
  error: "Username is already taken",
  value: params[:username]
) %>
```

### Card Component

Flexible container component for grouping related content.

#### Props
- `variant`: `:default`, `:elevated`, `:outlined`, `:ghost`
- `padding`: `:none`, `:sm`, `:default`, `:lg`, `:xl`
- `hover`: `true/false` - Adds hover effects
- `clickable`: `true/false` - Makes card focusable and adds cursor pointer

#### Examples
```erb
<%= render Ui::CardComponent.new(variant: :elevated, hover: true) do %>
  <h3 class="text-lg font-semibold mb-2">Card Title</h3>
  <p class="text-muted-foreground">Card content goes here.</p>
<% end %>
```

### Alert Component

Enhanced alert component for displaying messages with proper semantics and accessibility.

#### Props
- `type`: `:info`, `:success`, `:warning`, `:error`, `:danger`
- `title`: Optional title text
- `dismissable`: `true/false`
- `icon`: `true/false` - Show/hide icon

#### Examples
```erb
<%= render AlertComponent.new(type: :success, title: "Success!", dismissable: true) do %>
  Your changes have been saved successfully.
<% end %>

<%= render AlertComponent.new(type: :warning) do %>
  Please review your input before submitting.
<% end %>
```

### Modal Component

Accessible modal component with focus management and keyboard navigation.

#### Props
- `id`: Unique identifier
- `title`: Modal title
- `size`: `:sm`, `:default`, `:lg`, `:xl`, `:xxl`, `:full`
- `closable`: `true/false`
- `backdrop_close`: `true/false` - Close on backdrop click

#### Examples
```erb
<%= render Ui::ModalComponent.new(title: "Confirm Action", size: :sm) do %>
  <p class="mb-4">Are you sure you want to delete this item?</p>
  
  <% content_for :modal_footer do %>
    <%= render Ui::ButtonComponent.new(variant: :outline, data: { action: "click->modal#close" }) { "Cancel" } %>
    <%= render Ui::ButtonComponent.new(variant: :danger) { "Delete" } %>
  <% end %>
<% end %>
```

### Theme Toggle Component

Component for switching between light, dark, and system themes.

#### Props
- `show_text`: `true/false` - Display theme name text
- `variant`: `:default`, `:outline`, `:ghost`
- `size`: `:sm`, `:default`, `:lg`

#### Examples
```erb
<%= render Ui::ThemeToggleComponent.new(show_text: true, variant: :outline) %>
```

## Stimulus Controllers

### Modal Controller

Handles modal behavior including focus management, keyboard navigation, and accessibility.

#### Usage
```html
<div data-controller="modal" data-modal-closable-value="true">
  <!-- Modal content -->
</div>
```

#### Events
- `modal:opened` - Fired when modal opens
- `modal:closed` - Fired when modal closes

### Theme Controller

Manages theme switching and persistence with system preference detection.

#### Usage
```html
<div data-controller="theme">
  <button data-action="click->theme#toggle" data-theme-target="toggle">
    Toggle Theme
  </button>
</div>
```

#### Events
- `theme:changed` - Fired when theme changes

### Tooltip Controller

Provides accessible tooltips with configurable positioning and triggers.

#### Usage
```html
<button data-controller="tooltip" 
        data-tooltip-text-value="This is a tooltip"
        data-tooltip-placement-value="top">
  Hover me
</button>
```

#### Configuration
- `text`: Tooltip text content
- `placement`: `top`, `bottom`, `left`, `right`
- `trigger`: `hover`, `focus`, `click`, `manual`
- `delay`: Show delay in milliseconds
- `hideDelay`: Hide delay in milliseconds

### Dropdown Controller

Enhanced dropdown with keyboard navigation and accessibility features.

#### Usage
```html
<div data-controller="dropdown">
  <button data-dropdown-target="trigger" data-action="click->dropdown#toggle">
    Menu
  </button>
  <div data-dropdown-target="menu" class="hidden">
    <a href="#" data-dropdown-target="item" data-value="option1">Option 1</a>
    <a href="#" data-dropdown-target="item" data-value="option2">Option 2</a>
  </div>
</div>
```

#### Events
- `dropdown:opened` - Fired when dropdown opens
- `dropdown:closed` - Fired when dropdown closes
- `dropdown:itemSelected` - Fired when item is selected

### Alert Controller

Handles alert animations, auto-hide functionality, and dismissal.

#### Usage
```html
<div data-controller="alert" 
     data-alert-auto-hide-value="true" 
     data-alert-auto-hide-delay-value="5000">
  <!-- Alert content -->
</div>
```

#### Programmatic Usage
```javascript
// Create alerts programmatically
AlertController.success("Operation completed!", { autoHide: true })
AlertController.error("Something went wrong!", { dismissible: true })
```

## Dark Mode Support

### Implementation
The design system uses CSS custom properties for seamless theme switching:

```css
:root {
  --color-background: 255 255 255;
  --color-foreground: 15 23 42;
}

.dark {
  --color-background: 9 9 11;
  --color-foreground: 244 244 245;
}
```

### Usage in Components
```css
.my-component {
  background-color: rgb(var(--color-background));
  color: rgb(var(--color-foreground));
}
```

## Accessibility Features

### WCAG 2.1 AA Compliance
- ✅ **Color Contrast**: All color combinations meet 4.5:1 ratio requirement
- ✅ **Keyboard Navigation**: Full keyboard accessibility for all interactive elements
- ✅ **Screen Readers**: Proper ARIA labels and semantic HTML
- ✅ **Focus Management**: Visible focus indicators and logical tab order
- ✅ **Alternative Text**: Icons include appropriate aria-labels
- ✅ **Error Handling**: Clear error messages and validation feedback

### Keyboard Shortcuts
- `Tab` / `Shift+Tab`: Navigate through focusable elements
- `Enter` / `Space`: Activate buttons and links
- `Escape`: Close modals, dropdowns, and tooltips
- `Arrow Keys`: Navigate within dropdown menus
- `Home` / `End`: Jump to first/last item in lists

### Screen Reader Support
- Semantic HTML structure
- ARIA landmarks and roles
- Descriptive labels and help text
- Live regions for dynamic content updates

## Performance Considerations

### CSS Optimization
- CSS custom properties for efficient theme switching
- Minimal specificity to prevent cascade issues
- Purged unused styles in production
- Critical CSS inlined for above-the-fold content

### JavaScript Optimization
- Minimal Stimulus controller footprint
- Event delegation for better performance
- Intersection Observer for lazy loading
- RequestAnimationFrame for smooth animations

### Bundle Size
- Tailwind CSS purged: ~15KB gzipped
- Stimulus controllers: ~8KB gzipped
- Total component library: ~25KB gzipped

## Browser Support

- **Modern Browsers**: Full feature support
  - Chrome 88+
  - Firefox 84+
  - Safari 14+
  - Edge 88+

- **Legacy Browsers**: Graceful degradation
  - CSS custom properties fallbacks
  - Progressive enhancement for JavaScript features

## Development Workflow

### Adding New Components

1. **Create Ruby Component**
   ```ruby
   # app/components/ui/my_component.rb
   class Ui::MyComponent < ViewComponent::Base
     # Component logic
   end
   ```

2. **Create Template**
   ```erb
   <!-- app/components/ui/my_component.html.erb -->
   <div class="<%= classes %>">
     <%= content %>
   </div>
   ```

3. **Add Stimulus Controller (if needed)**
   ```javascript
   // app/javascript/controllers/my_component_controller.js
   import { Controller } from "@hotwired/stimulus"
   
   export default class extends Controller {
     // Controller logic
   }
   ```

4. **Add to Design System Showcase**
   - Update `/design_system` page with examples
   - Add usage documentation

### Testing Components

```ruby
# test/components/ui/my_component_test.rb
require "test_helper"

class Ui::MyComponentTest < ViewComponent::TestCase
  def test_renders_component
    render_inline(Ui::MyComponent.new)
    assert_text "Expected content"
  end
end
```

## Deployment

### Production Checklist
- ✅ Tailwind CSS purged and minified
- ✅ JavaScript controllers compiled and compressed
- ✅ CSS custom properties have fallbacks
- ✅ ARIA labels are properly internationalized
- ✅ Color contrast verified across all themes

### CDN Optimization
- Asset fingerprinting enabled
- Gzip compression configured
- Cache headers set appropriately
- Critical CSS inlined

## Migration Guide

### From Existing Components
1. **Audit Current Components**: Identify reusable patterns
2. **Map to Design System**: Choose appropriate DS components
3. **Update Templates**: Replace custom HTML with ViewComponents
4. **Add Accessibility**: Ensure WCAG compliance
5. **Test Thoroughly**: Verify functionality across browsers

### Breaking Changes
- None currently (initial release)

## Contributing

### Code Style
- Follow Rails conventions
- Use semantic HTML
- Implement ARIA attributes
- Include comprehensive tests
- Document all props and usage

### Pull Request Process
1. Create feature branch
2. Add/update tests
3. Update documentation
4. Test accessibility with screen reader
5. Verify browser compatibility

---

## Resources

- [ViewComponent Documentation](https://viewcomponent.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Stimulus Documentation](https://stimulus.hotwired.dev/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)