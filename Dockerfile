FROM public.ecr.aws/lambda/nodejs:18

# Install Playwright and system dependencies
RUN yum install -y \
    nss \
    nspr \
    atk \
    at-spi2-atk \
    cups-libs \
    libdrm \
    libxkbcommon \
    libxcomposite \
    libxdamage \
    libxrandr \
    libxfixes \
    mesa-libgbm \
    alsa-lib \
    gtk3 \
    libXScrnSaver \
    && yum clean all

# Copy package files
COPY package*.json ./

# Install dependencies (including dev dependencies for Playwright)
RUN npm ci

# Set Playwright browsers path
ENV PLAYWRIGHT_BROWSERS_PATH=/var/task/browsers

# Install Playwright browsers (dependencies already installed above)
RUN npx playwright install chromium

# Copy handler code
COPY lambda/ ${LAMBDA_TASK_ROOT}/
COPY tests/ ${LAMBDA_TASK_ROOT}/tests/

# Set the CMD to your handler
CMD [ "handler.runTest" ]

